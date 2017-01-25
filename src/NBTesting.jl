# Author: Cedric St-Jean
# with some code taken from NBInclude.jl, by Steven G. Johnson
__precompile__()

module NBTesting

using JSON

export nbtest, is_testing, @testing_noop

is_skip(line) = startswith(line, "#NBSKIP") || startswith(line, "# NBSKIP")

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
        if verbose > 0
            write(outfile, "info(\"Testing $path\"); flush(STDERR)\n")
        end
        for (counter, cell) in enumerate(nb["cells"])
            if cell["cell_type"] == "code" && !isempty(cell["source"])
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
                        write(outfile, "println(\"$first_line\"); ")
                        # Since the point of verbosity is partly to report on progress,
                        # we flush STDOUT.
                        write(outfile, "flush(STDOUT)\n")
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

""" `is_testing()` is true when called within `nbtest()`, and false otherwise. """
is_testing() = testing_flag[]

function nbtest(path::AbstractString; kwargs...)
    fname = nbtranslate(path; kwargs...)
    testing() do 
        include(fname)
    end
end

noop(args...; kwargs...) = nothing

"""    @testing_noop fun1 fun2 ...

This macro doesn't do anything under normal execution, when this macro is run by `nbtest`,
it turns the given function names into no-ops. It's primarily meant for output functions
like `plot`:

    @testing_noop plot     # put this near the top of your notebook
"""
macro testing_noop(funs::Symbol...)
    esc(quote
        if $NBTesting.is_testing()
            $([:(@eval $f = $NBTesting.noop) for f in funs]...)
        end
    end)
end

end # module
