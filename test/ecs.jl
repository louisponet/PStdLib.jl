#%%
using PStdLib.ECS
using PStdLib: DataStructures
import PStdLib.ECS: Manager, ComponentData, Component, Entity, System
using PStdLib.DataStructures
using PStdLib.Geometry
using PStdLib
#%%
@component_with_kw struct Spring
	center::Point3{Float64} = zero(Point3{Float64})
	k     ::Float64  = 0.01
	damping::Float64 = 0.000
end
@component struct Spatial <: ComponentData
	p::Vec3{Float64}
	v::Vec3{Float64}
end
struct Oscillator <: System end

ECS.requested_components(::Oscillator) = (Spatial, Spring)

function ECS.update(::Oscillator, m::ECS.AbstractManager)
	spat = m[Spatial]
	spring = m[Spring]
	@inbounds for e in entities(spat, spring)
    	e_spat = spat[e]
    	spr = spring[e]
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		spat[e] = Spatial(new_p, new_v)
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

push!(m, SystemStage(:basic, [O]))
for i = 1:5
	ECS.update_systems(m)
end

@test sum(map(x->m[Spatial, Entity(x)].p[1], 1:100)) == -5605.33

ECS.preferred_component_type(::Type{Spring}) = SharedComponent
m = Manager(SystemStage(:basic,[O]))
create_fill(m)
for i = 1:5
	ECS.update_systems(m)
end
@test sum(map(x->m[Spatial, Entity(x)].p[1], 1:100)) == -5605.33
