using Revise
using PStdLib: ECS
using PStdLib: VectorTypes
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System, SystemData
import PStdLib.VectorTypes: GappedVector
using PStdLib.Geometry
using PStdLib

mutable struct TimingData <: ComponentData
	time     ::Float64
	dtime    ::Float64
	reversed ::Bool
end

@with_kw struct Spring <: ComponentData
	center::Point3{Float64} = zero(Point3{Float64})
	k     ::Float64  = 0.01
	damping::Float64 = 0.000
end

struct Spatial <: ComponentData
	p::Vec3{Float64}
	v::Vec3{Float64}
end

struct Oscillator <: System
	data ::SystemData
end

Oscillator(m::Manager) = Oscillator(SystemData(m, (Spatial, Spring), (TimingData)))

function update(sys::Oscillator)
	spat   = sys[Spatial]
	spring = sys[Spring]
	td     = sys[TimingData]
	dt     = td.dtime
	sorted_comps = sort([spat, spring], by=length)
	test_es = eachindex(sorted_comps[1])
	for e in test_es
		if has(sorted_comps[2], e)
			e_spat   = spat[e]
			v_prev   = e_spat.velocity
			new_v    = v_prev - (e_spat.position - spr.center) * spr.k - v_prev * spr.damping
			new_p    = e_spat.position + v_prev * dt
			ECS.overwrite!(spat, Spatial(new_p, new_v), e)
		end
	end
end

m = Manager(Spatial, Spring, TimingData)

es = Entity[]
for i = 1:10
	push!(es, Entity(m))
end
using BenchmarkTools
m[Spatial, [es[2], es[3]]] = Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0))
m[Speed, es[3]] = Speed(40.0)
ECS.remove_entity!(m, es[2])
ECS.valid_entities(m)
m[es[2]]
m[Speed]
m[Spatial].data.data

Entity(m)
