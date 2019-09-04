#%%
using PStdLib: ECS
using PStdLib: DataStructures
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System, SystemData
using PStdLib.DataStructures
using PStdLib.Geometry
using PStdLib
#%%
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
	spat, spring = sys[Spatial], sys[Spring]
	@inbounds for ((id1, e_spat), (id2, spr)) in zip(enumerate(spat), enumerate(spring))
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		spat[id1] = Spatial(new_p, new_v)
	end
end

function pointer_update(sys::Oscillator)
	map(sys, Spatial, Spring) do spat, spring
		@inbounds for ((id1, p_spat), (id2, p_spr)) in pointer_zip(spat, spring)
			e_spat = unsafe_load(p_spat)
			spr = unsafe_load(p_spr)
			v_prev   = e_spat.v
			new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
			new_p    = e_spat.p + v_prev * 1.0
			unsafe_store!(p_spat, Spatial(new_p, new_v))
		end
	end
end

m = Manager(Spatial, Spring)

function create_fill(m)
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
create_fill(m)
O = Oscillator(m)

for i = 1:3
	update(O)
end
for i = 1:2
	pointer_update(O)
end

@test m[Spatial, Entity(230)].p[2] == 5.8006

m = Manager((Spatial,), (Spring,))
create_fill(m)
O = Oscillator(m)
for i = 1:3
	update(O)
end
for i = 1:2
	pointer_update(O)
end
@test m[Spatial, Entity(230)].p[2] == 5.8006
