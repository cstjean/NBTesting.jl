module NBTest_Water_Analysis
using NBTesting
is_testing = true

NBTesting.clear_test_times!()

# ----------------------------------- 
println("# Top title"); flush(STDOUT)

# Cell #1
using NBTesting
using Base.Test

using PyPlot

# This defines 
#     plot(args...; kwargs...) = nothing
# but only during testing.
@testing_noop plot

# ----------------------------------- 
println("### Basic Arithmetic"); flush(STDOUT)

# Cell #2
x = 10 / 2
@test x+x == 10
@test 6*10 == 60

# Cell #3
N = is_testing ? 5 : 100

srand(1)
M1 = ones(N, N)
M2 = rand(N, N);

if is_testing
    @test 30 < sum(M1 * M2) < 100
end

sum(M1 * M2)

# ----------------------------------- 
println("#### Some plot"); flush(STDOUT)

# Cell #4
plot([1,2,1]);

end  # module 
