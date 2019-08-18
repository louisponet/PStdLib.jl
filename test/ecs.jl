#%%
using PStdLib: ECS
using PStdLib: VectorTypes
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System, SystemData
using PStdLib.VectorTypes
using PStdLib.Geometry
using PStdLib

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

function Oscillator(m::Manager)
	O = Oscillator(SystemData((Spatial, Spring), m))
	push!(m.systems, O)
	return O
end

function update(sys::Oscillator)
	spat   = sys[Spatial]
	spring = sys[Spring]
	dt     = 1.0
	for (it, (e_spat, spr)) in enumerate(zip(spat, spring))
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * dt
		spat[it] = Spatial(new_p, new_v)
	end
end


m = Manager(Spatial, Spring, init_size=1000000)

function create_fill(m)
	spat   = m[Spatial]
	spring = m[Spring]
	for i = 1:1000000
		e = Entity(m)
		spat[e.id] = Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0))
		if i%2 == 0
			spring[e.id] = Spring()
		end
	end
	# empty!(m)
end
create_fill(m)
#%%

O = Oscillator(m)
for i = 1:5
	update(O)
end

@test m[Spatial, Entity(230)].p[2] == 5.8006

#%%
