# NBTesting

[![Build Status](https://travis-ci.org/cstjean/NBTesting.jl.svg?branch=master)](https://travis-ci.org/cstjean/NBTesting.jl)

[![Coverage Status](https://coveralls.io/repos/cstjean/NBTesting.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/cstjean/NBTesting.jl?branch=master)

[![codecov.io](http://codecov.io/github/cstjean/NBTesting.jl/coverage.svg?branch=master)](http://codecov.io/github/cstjean/NBTesting.jl?branch=master)

`nbtest` produces a git-friendly `.jl` file with the tests before running them. It can
be produced without running the tests by calling `NBTesting.nbtranslate(filename)`.

The code in a cell that comes after `# NBSKIP` is ignored.

```
@test 5+5 == 10
# NBSKIP
@test 10*10 == This doesn't even have to be valid Julia code; it's not saved
```




TODO

- export `is_testing()` which returns true iff we're running a test (use a dlet over the
whole module - we want `include` to work)
- @testset. Beware that this may create new scopes
- Create a dummy module for Plots, that exports the same variables, but every function is a no-op