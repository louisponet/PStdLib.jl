using Test

@time @testset "math" begin include("math.jl") end
@time @testset "Geometry" begin include("Geometry.jl") end
@time @testset "string" begin include("string.jl") end
@time @testset "array" begin include("array.jl") end
@time @testset "ThreadCaches" begin include("ThreadCaches.jl") end
@time @testset "BLASCaches"   begin include("BLASCaches.jl") end
