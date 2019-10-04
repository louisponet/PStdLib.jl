using BenchmarkTools
using PStdLib.DataStructures
using Random

rand_setup =  (
	Random.seed!(1234);
	ids1 = rand(1:30000, 1000);
	ids2 = rand(1:30000, 1000);
)

gc_teardown = quote
	Base.GC.gc()
end

SUITE = BenchmarkGroup()


#### ECS
using PStdLib.ECS
using PStdLib.Parameters
using PStdLib.Geometry


@with_kw struct Spring <: ComponentData
	center::Point3{Float64} = zero(Point3{Float64})
	k     ::Float64  = 0.01
	damping::Float64 = 0.000
end
struct Spatial <: ComponentData
	p::Vec3{Float64}
	v::Vec3{Float64}
end
struct Oscillator <: System end

ECS.requested_components(::Oscillator) = (Spatial, Spring)

function ecs_creation()
	m = Manager(Spatial, Spring)
end

SUITE["ECS"] = BenchmarkGroup()
SUITE["ECS"]["creation"] = @benchmarkable ecs_creation()
	
function create_fill_ecs(m)
	map(m, Spatial, Spring) do spat, spring
		for i = 1:1000000
			e = Entity(m, i)
			spat[e] = Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0))
			if i%2 == 0
				spring[e] = Spring()
			end
		end
	end
end

function (::Oscillator)(spat, spring)
	for ((id1, e_spat), spr) in zip(enumerate(spat), spring)
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		@inbounds spat[id1] = Spatial(new_p, new_v)
	end
end

function (::Oscillator)(spat, spring, ::Val{:pointer})
	@inbounds for (p_spat, p_spr) in pointer_zip(spat, spring)
		e_spat = unsafe_load(p_spat)
		spr = unsafe_load(p_spr)
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		unsafe_store!(p_spat, Spatial(new_p, new_v))
	end
end

SUITE["ECS"]["create and fill entities"] =
	@benchmarkable create_fill_ecs(m) setup=(m=Manager(Spatial, Spring)) 
	# @benchmarkable create_fill(m) setup=(m=Manager(Spatial, Spring)) evals=1

SUITE["ECS"]["fill entities"] =
	@benchmarkable create_fill_ecs(m) setup=(m=Manager(Spatial, Spring);create_fill_ecs(m)) 
	# @benchmarkable create_fill(m) setup=(m=Manager(Spatial, Spring);create_fill(m)) evals=10000 samples=1

SUITE["ECS"]["update oscillator"] =
	@benchmarkable o(m[Spatial], m[Spring]) setup=(m=Manager(Spatial, Spring); o=Oscillator(); push!(m.systems, o); create_fill_ecs(m))


SUITE["ECS"]["update oscillator pointers"] =
	@benchmarkable o(m[Spatial], m[Spring], Val{:pointer}()) setup=(m=Manager(Spatial, Spring); o=Oscillator(); push!(m.systems, o); create_fill_ecs(m))

SUITE["ECS"]["update oscillator; shared Spring"] =
	@benchmarkable o(m[Spatial], m[Spring]) setup=(m=Manager((Spatial,), (Spring,)); o=Oscillator(); push!(m.systems, o); create_fill_ecs(m))

SUITE["ECS"]["update oscillator pointers; shared Spring"] =
	@benchmarkable o(m[Spatial], m[Spring], Val{:pointer}()) setup=(m=Manager((Spatial,), (Spring,)); o=Oscillator(); push!(m.systems, o); create_fill_ecs(m))








