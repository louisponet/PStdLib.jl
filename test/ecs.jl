#%%
using PStdLib: ECS
using PStdLib: DataStructures
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System, SystemData
using PStdLib.DataStructures
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
	t=(s1, s2) -> begin
		for (it, (e_spat, spr)) in enumerate(zip(s1, s2))
			v_prev   = e_spat.v
			new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
			new_p    = e_spat.p + v_prev * dt
			s1[it] = Spatial(new_p, new_v)
		end
	end
	t(spat,spring)
end
m = Manager(Spatial, Spring)

function create_fill(m)
	spat   = m[Spatial]
	spring = m[Spring]
	for i = 1:1000000
		e = Entity(m, i)
		spat[e] = Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0))
		if i%2 == 0
			spring[e] = Spring()
		end
	end
end
create_fill(m)
O = Oscillator(m)

for i = 1:5
	update(O)
end

@test m[Spatial, Entity(230)].p[2] == 5.8006
