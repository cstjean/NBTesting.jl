# Author: Cedric St-Jean
# with some code taken from NBInclude.jl, by Steven G. Johnson
__precompile__()

module NBTesting

using JSON

export nbtest, nbtranslate, is_testing, @testing_noop

is_skip(line) = startswith(line, "#NBSKIP") || startswith(line, "# NBSKIP")


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
                     verbose=5)
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
        write(outfile, string("module ", module_name, "\n\n"))
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
                    write(outfile, string("# Cell #", cellnum, "\n"))
                end
                for line in lines
                    if is_skip(line) break end
                    write(outfile, line)
                    write(outfile, "\n")
                end
                write(outfile, "\n")
            elseif cell["cell_type"] == "markdown" && !isempty(cell["source"])
                first_line = split(join(cell["source"]), "\n")[1]
                # "#"[1] because of a silly ESS (Emacs) code-formatting bug.
                n_pound = findfirst(x->x!="#"[1], first_line) - 1
                if 1 <= n_pound
                    if n_pound <= verbose
                        write(outfile, "# ----------------------------------- \n")
                        write(outfile, "println(\"$first_line\"); ")
                        # Since the point of verbosity is partly to report on progress,
                        # we flush STDOUT.
                        write(outfile, "flush(STDOUT)\n\n")
                    else
                        write(outfile, first_line)
                        write(outfile, "\n")
                    end
                end
            end
        end
        write(outfile, "end  # module \n")
    end
    return outfile_name
end

const testing_flag = fill(false)
function testing(f::Function, val=true)
    old_val = testing_flag[]
    testing_flag[] = val
    try
        f()
    finally
        testing_flag[] = old_val
    end
end
testing(fname::AbstractString) = testing(()->include(fname))

# Hey! I'm pretty sure that this could be an exported `global is_testing = false`, where
# we would simply add `is_testing = true` at the top of the .jl file.
""" `is_testing()` is true when called within `nbtest()`, and false otherwise. """
is_testing() = testing_flag[]


"""     nbtest(path; outfile_name=..., verbose=5)

Translates the given .ipynb file into a .jl file for testing, then executes the file.

 - All code following #NBSKIP within a cell will be ignored
 - `outfile_name` defaults to the name of the .ipynb file, with a .jl extension.
 - NBTest wraps the notebook code inside a module called `NBTest_[Notebook name]`.
 - All headers that start with N pound signs (#) will be turned into print statements,
whenever `N <= verbose` (so the higher `verbose`, the more titles are printed)
"""
function nbtest(path::AbstractString; verbose=5, kwargs...)
    fname = nbtranslate(path; verbose=verbose, kwargs...)
    if verbose > 0
        info("Testing $path"); flush(STDERR) end
    return testing(fname)
end


noop(args...; kwargs...) = nothing

"""    @testing_noop fun1 fun2 ...

This macro doesn't do anything under normal execution, but when it is run by `nbtest`,
it turns the given function names into no-ops. It's primarily meant for disabling output
functions like `plot` during testing. For example:

    @testing_noop plot
    #NBSKIP
    using Plots

This will avoid loading Plots at all during testing.
"""
macro testing_noop(funs::Symbol...)
    esc(quote
        if $NBTesting.is_testing()
            $([:(@eval $f = $NBTesting.noop) for f in funs]...)
        end
    end)
end

end # module
