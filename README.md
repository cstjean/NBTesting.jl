# NBTesting

[![Build Status](https://travis-ci.org/cstjean/NBTesting.jl.svg?branch=master)](https://travis-ci.org/cstjean/NBTesting.jl)

[![Coverage Status](https://coveralls.io/repos/cstjean/NBTesting.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cstjean/NBTesting.jl?branch=master)

[![codecov.io](http://codecov.io/github/cstjean/NBTesting.jl/coverage.svg?branch=master)](http://codecov.io/github/cstjean/NBTesting.jl?branch=master)

NBTesting is a simple testing utility for Jupyter notebooks. How it works:

1. [Add tests to your notebook](test/Test_notebook.ipynb) using `Base.Test`, or your
favorite testing framework.
2. Use `nbtest("Test_notebook.ipynb")` to run the tests. This will create and execute 
[`Test_notebook.jl`](test/Test_notebook.jl), with the code from your notebook. 
3. (Optional) Track this file with git

`nbtest` will mostly run the notebook code as is (similar to
[NBInclude.jl](https://github.com/stevengj/NBInclude.jl)), but it provides [a few ways to
control which code gets executed when](test/Test_notebook.ipynb), and a `verbose=...`
option for printing the headers (on by default - see `?nbtest` for details). The code is
run inside a module called `NBTest_[Notebook name]`, to isolate it from the current
environment, and to make it easier to inspect the state of variables if a test fails.

To get the .jl file without executing it, use `nbtranslate(...)`
