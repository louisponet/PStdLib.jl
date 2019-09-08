#%%
using PStdLib: ECS
using PStdLib: DataStructures
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System
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
struct Oscillator <: System end

ECS.requested_components(::Oscillator) = (Spatial, Spring)

function (::Oscillator)(spat, spring)
	@inbounds for (eid, (id1, e_spat), spr) in zip(enumerate(spat), spring)
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		spat[id1] = Spatial(new_p, new_v)
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

m = Manager(Spatial, Spring)

function create_fill(m)
	map(m, Spatial, Spring) do spat, spring
		for i = 1:100
			e = Entity(m, i)
			spat[e] = Spatial(Point3(Float64(i),1.0,1.0), Vec3(1.0,Float64(i),1.0))
			if i%2 == 0
				spring[e] = Spring(k=Float64(i)/100)
			end
		end
	end
end
create_fill(m)
O = Oscillator()

push!(m.systems, O)
for i = 1:3
	ECS.update_systems(m)
end
for i = 1:2
	O(m[Spatial], m[Spring], Val{:pointer}())
end


@test sum(map(x->m[Spatial, Entity(x)].p[1], 1:100)) == -5605.33

m = Manager((Spatial,), (Spring,))
create_fill(m)
O = Oscillator()

push!(m.systems, O)
for i = 1:3
	ECS.update_systems(m)
end
for i = 1:2
	O(m[Spatial], m[Spring], Val{:pointer}())
end
@test sum(map(x->m[Spatial, Entity(x)].p[1], 1:100)) == -5605.33
