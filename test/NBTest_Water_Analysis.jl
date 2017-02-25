module NBTest_Water_Analysis

# ----------------------------------- 
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
@test x==1

# ----------------------------------- 
println("### Basic Arithmetic"); flush(STDOUT)

# Cell #3
@test 5+5 == 10
@test 6*10 == 60

# Cell #4
# More complicated code and test
srand(1)
M1 = ones(5,5)
M2 = rand(5,5);

# Cell #5
@test 30 < sum(M1 * M2) < 100

# ----------------------------------- 
println("#### Some plot"); flush(STDOUT)

# Cell #6
plot([1,2,1])

end  # module 
