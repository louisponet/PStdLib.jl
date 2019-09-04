using BenchmarkTools
using PStdLib.DataStructures
using Random

rand_setup = () -> (
	Random.seed!(1234);
	ids1 = rand(1:30000, 1000);
	ids2 = rand(1:30000, 1000);
)

gc_teardown = quote
	Base.GC.gc()
end

SUITE = BenchmarkGroup()

SUITE["PackedIntSet"] = BenchmarkGroup()


function create_fill_packed(ids1)
	y = PackedIntSet()
	for i in ids1
		push!(y, i)
	end
end

SUITE["PackedIntSet"]["create_fill"] =
	@benchmarkable create_fill_packed(ids1) setup=rand_setup teardown=gc_teardown

SUITE["PackedIntSet"]["in while not in"] =
	@benchmarkable in(23, y) evals=1000 setup=(y = PackedIntSet();)
SUITE["PackedIntSet"]["in while in"] =
	@benchmarkable in(5199, y) evals=1000 setup=(y=PackedIntSet(); push!(y, 5199))

function pop_push(y)
	pop!(y, 5199)
	push!(y, 5199)
end

SUITE["PackedIntSet"]["pop push"] = @benchmarkable pop_push(y) setup=(y=PackedIntSet(); push!(y, 5199))

function iterate_one_bench(x)
	t = 0
	for i in x.packed
		t += i
	end
	return t
end
function iterate_two_bench(x,y)
	t = 0
	for i in x.packed
		if in(i, y)
			t += i
		end
	end
	return t
end

x_y_setup = (
	Random.seed!(1234);
	ids1 = rand(1:30000, 1000);
	ids2 = rand(1:30000, 1000);
	x = PackedIntSet(ids1);
	y = PackedIntSet(ids2);
)

SUITE["PackedIntSet"]["iterate one"] =
	@benchmarkable iterate_one_bench(x) setup=x_y_setup

SUITE["PackedIntSet"]["iterate two"] =
	@benchmarkable iterate_two_bench(x,y) setup=x_y_setup

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

struct Oscillator{S<:SystemData} <: System
	data::S
end

function Oscillator(m::Manager)
	O = Oscillator(SystemData((Spatial, Spring), m))
	push!(m.systems, O)
	return O
end

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

function update_map(sys::Oscillator)
	map(sys, Spatial, Spring) do spat, spring
		for ((id1, e_spat), spr) in zip(enumerate(spat), spring)
			v_prev   = e_spat.v
			new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
			new_p    = e_spat.p + v_prev * 1.0
			@inbounds spat[id1] = Spatial(new_p, new_v)
		end
	end
end

function update(sys::Oscillator)
	spat, spring = sys[Spatial], sys[Spring]
	for ((id1, e_spat), spr) in zip(enumerate(spat), spring)
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		@inbounds spat[id1] = Spatial(new_p, new_v)
	end
end

function update_pointer(sys::Oscillator)
	spat, spring   = sys[Spatial], sys[Spring]
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
	@benchmarkable update(o) setup=(m=Manager(Spatial, Spring); o=Oscillator(m); create_fill_ecs(m))

SUITE["ECS"]["update oscillator mapped"] =
	@benchmarkable update_map(o) setup=(m=Manager(Spatial, Spring); o=Oscillator(m); create_fill_ecs(m))

SUITE["ECS"]["update oscillator pointers"] =
	@benchmarkable update_pointer(o) setup=(m=Manager(Spatial, Spring); o=Oscillator(m); create_fill_ecs(m))

SUITE["ECS"]["update oscillator; shared Spring"] =
	@benchmarkable update(o) setup=(m=Manager((Spatial,), (Spring,)); o=Oscillator(m); create_fill_ecs(m))

SUITE["ECS"]["update oscillator mapped; shared Spring"] =
	@benchmarkable update_map(o) setup=(m=Manager((Spatial,), (Spring,)); o=Oscillator(m); create_fill_ecs(m))
SUITE["ECS"]["update oscillator pointers; shared Spring"] =
	@benchmarkable update_pointer(o) setup=(m=Manager((Spatial,), (Spring,)); o=Oscillator(m); create_fill_ecs(m))








