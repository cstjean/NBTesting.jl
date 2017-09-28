# Author: Cedric St-Jean
# with some code taken from NBInclude.jl, by Steven G. Johnson
__precompile__()

module NBTesting

include("scrub_stderr.jl")

using JSON

export nbtest, is_testing, @testing_noop

is_skip(line) = startswith(line, "#NBSKIP") || startswith(line, "# NBSKIP")

const last_test_times = []
clear_test_times!() = empty!(last_test_times)
macro store_time(expr)
    esc(quote
        push!($NBTesting.last_test_times, ($(Expr(:quote, expr)), @elapsed($expr)))
        end)
end

const current_section = fill("")

"""     nbtranslate(path; outfile_name=..., verbose=5)

Translates the given .ipynb file into a .jl file, for testing.

 - All code following #NBSKIP within a cell will be ignored
 - `outfile_name` defaults to the name of the .ipynb file, preceded by `NBTest_`, and
   with a .jl extension.
 - The code will be wrapped inside a module called `NBTest_[Notebook name]`.
 - All headers that start with N pound signs (#) will be turned into print statements,
whenever `N <= verbose` (so the higher `verbose`, the more titles are printed)
"""
function nbtranslate(path::AbstractString;
                     outfile_name=joinpath(dirname(path),
                                           "NBTest_" * splitext(basename(path))[1]*".jl"),
                     verbose=5, time_cells=false)
    _, ext = splitext(path)
    @assert ext == ".ipynb" "nbtranslate only accepts notebook files (.ipynb)"

    # sleep a bit to process file requests from other nodes
    nprocs()>1 && sleep(0.005)
    nb = open(JSON.parse, path, "r")

    # check for an acceptable notebook:
    nb["nbformat"] == 4 || error("unrecognized notebook format ", nb["nbformat"])
    lang = lowercase(nb["metadata"]["language_info"]["name"])
    lang == "julia" || error("notebook is for unregognized language $lang")

    shell_or_help = r"^\s*[;?]" # pattern for shell command or help
    
    module_name = splitext(basename(outfile_name))[1]
    open(outfile_name, "w") do outfile
        write(outfile, string("module ", module_name, "\n"))
        write(outfile, "using NBTesting\n")  # to avoid ambiguity warning for is_testing
        write(outfile, "is_testing = true\n\n")
        write(outfile, "NBTesting.clear_test_times!()\n\n")
        counter = 0
        for cell in nb["cells"]
            if cell["cell_type"] == "code" && !isempty(cell["source"])
                counter += 1
                s = join(cell["source"])
                isempty(strip(s)) && continue # Jupyter doesn't number empty cells
                ismatch(shell_or_help, s) && continue
                cellnum = string(counter)
                
                lines = split(s, "\n")
                if !is_skip(lines[1])
                    if time_cells
                        lines = vcat(["nbtest_temp_time = Base.time_ns()"],
                                     lines,
                                     ["push!(NBTesting.last_test_times, ($counter, ((Base.time_ns)() - nbtest_temp_time)/1.e9))"])
                    end
                    write(outfile, string("# Cell #", cellnum, "\n"))
                    for line in lines
                        if is_skip(line) break end
                        write(outfile, line)
                        write(outfile, "\n")
                    end
                    write(outfile, "\n")
                end
            elseif cell["cell_type"] == "markdown" && !isempty(cell["source"])
                first_line = split(join(cell["source"]), "\n")[1]
                n_pound = findfirst(x->x!='#', first_line) - 1
                if 1 <= n_pound
                    if n_pound <= verbose
                        write(outfile, "# ----------------------------------- \n")
                        write(outfile, "println(\"$first_line\"); ")
                        # Since the point of verbosity is partly to report on progress,
                        # we flush STDOUT.
                        write(outfile, "flush(STDOUT)\n")
                    else
                        write(outfile, first_line)
                    end
                    write(outfile, "NBTesting.current_section[] = \"$first_line\"\n\n")
                end
            end
        end
        write(outfile, "end  # module")
    end
    return outfile_name
end


""" `is_testing` is true when called within `nbtest()`, and false otherwise. """
is_testing = false


"""     nbtest(path; outfile_name=..., verbose=5, keep_module=false, time_cells=false)

Translates the given .ipynb file into a .jl file for testing, then executes the file.

 - All code following #NBSKIP within a cell will be ignored
 - `outfile_name` defaults to the name of the .ipynb file, with a .jl extension.
 - NBTest wraps the notebook code inside a module called `NBTest_[Notebook name]`.
 - All headers that start with N pound signs (#) will be turned into print statements,
whenever `N <= verbose` (so the higher `verbose`, the more titles are printed)
 - If `time_cells=true`, each cell's running time is saved as `(Cell#, runtime)` in
`NBTesting.last_test_times`. See the generated .jl file to match the `Cell#`.
 - If `keep_module==true`, the second time that `nbtest(path)` is run for the same path,
the code will be evaluated in the same `NBTest_...` module instead of creating a new
module with the same name.
"""
function nbtest(path::AbstractString; verbose=5, keep_module=false, kwargs...)
    fname = nbtranslate(path; verbose=verbose, kwargs...)
    if verbose > 0
        info("Testing $path"); flush(STDERR) end
    current_section[] = ""  # just to make sure it's not misleading
    if keep_module
        return include_in_module(fname)
    else
        return include(fname)
    end
end

function include_in_module(nb_file::String)
    # I make a lot of effort to be able to run the code with `include`
    tmp_nb_file = splitext(nb_file)[1] * "_tmp.jl"
    local mod
    try
        mod_sym = open(tmp_nb_file, "w") do out
            println(out, "# Comment line so that the line numbers of this temp file lines up with the real one")
            lines = split(open(readstring, nb_file, "r"), '\n')
            for line in lines[2:end-1]
                write(out, line)
                write(out, "\n")
            end
            module_, mod_name = split(lines[1], " ")
            @assert module_ == "module"
            Symbol(mod_name)
        end
        if isdefined(Main, mod_sym)
            mod = eval(Main, mod_sym)
        else
            # module doesn't exist; just incude the file normally
            return include(nb_file)
        end
        eval(mod, :($NBTesting.sinclude($tmp_nb_file)))
        return mod
    finally
        rm(tmp_nb_file)
    end
end

noop(args...; kwargs...) = nothing

"""    @testing_noop fun1 fun2 ...

This macro doesn't do anything under normal execution, but when it is run by `nbtest`,
it turns the given function names into no-ops. It's primarily meant for disabling output
functions like `plot` during testing. For example:

    using Plots
    @testing_noop plot plot! vline!
"""
macro testing_noop(funs::Symbol...)
    esc(quote
        if is_testing
            $([:(@eval $f = $NBTesting.noop) for f in funs]...)
        end
    end)
end

end # module
