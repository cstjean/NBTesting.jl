module NBTest_Test_notebook

println("# Top title"); flush(STDOUT)
# Cell #1
using NBTesting
using Base.Test

# This defines 
#    plot(args...; kwargs...) = nothing
# but only during testing.
@testing_noop plot

# Cell #2
x = 10 - 9

# Cell #3
@test x==1

println("### Basic Arithmetic"); flush(STDOUT)
# Cell #4
@test 5+5 == 10
@test 6*10 == 60

println("#### Interesting plot"); flush(STDOUT)
# Cell #5
plot([1,2,1])


end  # module 
