using Test
@testset "datastructures" begin include("datastructures.jl")  end
@testset "ecs"            begin include("ecs.jl")             end
@testset "math"           begin include("math.jl")            end
@testset "Geometry"       begin include("Geometry.jl")        end
@testset "string"         begin include("string.jl")          end
@testset "array"          begin include("array.jl")           end
@testset "ThreadCaches"   begin include("ThreadCaches.jl")    end
@testset "BLASCaches"     begin include("BLASCaches.jl")      end
