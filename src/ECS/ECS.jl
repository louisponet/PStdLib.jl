module ECS
	using ..VectorTypes
	import ..getfirst

	const VECTORTYPE = LooseVector
	abstract type AbstractManager end

	struct Entity
		id::Int
	end

	id(e::Entity) = e.id

	function Entity(m::AbstractManager)
		if !isempty(free_entities(m))
			e = pop!(free_entities(m))
			entities(m)[id(e)] = e
			return e
		end
		n = length(entities(m)) + 1
		e = Entity(n)
		push!(m.entities, e)
		return e
	end

	Base.getindex(v::AbstractVector, e::Entity) = v[id(e)]
	# Base.setindex!(vec::AbstractVector, v, e::Entity) = setindex!(vec, v, id(e))
	# Base.deleteat!(vec::AbstractVector, e::Entity) = deleteat!(vec, id(e))

	abstract type ComponentData end

	abstract type AbstractComponent{T<:ComponentData} end

	Base.eltype(::AbstractComponent{T}) where T = T

	data(c::AbstractComponent) = c.data
	has(c::AbstractComponent, e::Entity) = in(id(e), data(c))
	Base.getindex(c::AbstractComponent, e::Entity) =data(c)[e]

	struct Component{T} <: AbstractComponent{T}
		id  ::Int
		data::VECTORTYPE{T}
		function Component{T}(m::AbstractManager, init_size) where {T<:ComponentData}
			n = length(components(m)) + 1
			v = VECTORTYPE{T}(init_size)
			c = new{T}(n, v)
			m.components[T] = c
			return c
		end
	end

	struct ComponentDict <: AbstractDict{DataType, Component}
		dict::Dict{DataType, Component}
	end

	ComponentDict() = ComponentDict(Dict{DataType, Component}())

	Base.getindex(c::ComponentDict, ::Type{T}) where {T<:ComponentData} =
		c.dict[T]::Component{T}

	Base.setindex!(c::ComponentDict, v, ::Type{T}) where {T<:ComponentData} =
		c.dict[T] = v

	Base.length(c::ComponentDict) = length(c.dict)

	Base.iterate(c::ComponentDict, args...) = iterate(c.dict, args...)

	#maybe this shouldn't be called remove_entity!
	remove_entity!(c::AbstractComponent, e::Entity) =
		deleteat!(c.data, id(e))

	struct SharedComponent{T<:ComponentData} <: AbstractComponent{T}
		id    ::Int
		data  ::VECTORTYPE{T} #These are basically the ids
		shared::Vector{T}
	end

	abstract type System end

	struct Manager <: AbstractManager
		entities     ::Vector{Entity}
		free_entities::Vector{Entity}
		components   ::ComponentDict
		systems      ::Vector{System}
	end

	Base.getindex(c::Component, i)       = getindex(data(c), i)
	Base.getindex(c::SharedComponent, i) = getindex(c.shared[data(c)[i]])

	Base.setindex!(c::Component, v, i)   = setindex!(c.data, v, i)
	Base.zip(cs::Component...) = zip(data.(cs)...)


	function Base.setindex!(c::SharedComponent,v, i)
		id = findfirst(isequal(v), c.shared)
		if id == nothing
			id = length(c.shared) + 1
			push!(c.shared, v)
		end
		c.data[i] = id
	end

	data(s::System) =
		s.data

	#Each system should have this as it's data field, or data() needs to be
	#overloaded
	#TODO: Speedup: maybe using Tuples of components might be better,
	#               since technically one should know what components to use.
	struct SystemData
		engaged::Bool 
		#These are the components that the system will work with
		components::ComponentDict
	end

	function SystemData(component_types::NTuple, manager::Manager, engaged=true)
		comps = ComponentDict()
		for ct in component_types
			comps[ct] = manager[ct]
		end
		return SystemData(engaged, comps)
	end

	isengaged(s::System) = data(s).engaged
	engage!(s::System)   = data(s).engaged = true
	disengage!(s::System)= data(s).engaged = false

	Base.getindex(s::System, ::Type{T}) where {T<:ComponentData} =
		data(s).components[T]::Component{T}

	Manager() = Manager(Entity[], Entity[], ComponentDict(), System[])

	function Manager(components...; init_size=1000)
		m = Manager()
		comps = ComponentDict()
		for c in components
			comps[c] = Component{c}(m, init_size)
		end
		return m
	end

	components(m::Manager) = m.components
	entities(m::Manager)   = m.entities
	free_entities(m::Manager) = m.free_entities
	valid_entities(m::Manager) = filter(x -> x.id != 0, m.entities)
	systems(m::Manager)    = m.systems

	function all_components(::Type{T}, manager::Manager) where {T<:ComponentData}
		comps = AbstractComponent[]
		for c in components(manager)
			if eltype(c) <: T
				push!(comps, c)
			end
		end
		return comps
	end

	function entity_assert(m::Manager, e::Entity)
		es = entities(m)
		@assert length(es) >= e.id "$e was never initiated."
		@assert es[e] != Entity(0) "$e was removed previously."
	end

	Base.getindex(m::Manager, ::Type{T}) where {T<:ComponentData} =
		components(m)[T]

	function Base.getindex(m::Manager, e::Entity)
		entity_assert(m, e)		
		data = ComponentData[]
		for c in components(m)
			if has(c, e)
				push!(data, c[e])
			end
		end
		return data
	end

	#TODO: Performance
	function Base.getindex(m::Manager, ::Type{T}, e::Entity) where {T<:ComponentData}
		entity_assert(m, e)
		return m[T][id(e)]
	end

	function Base.setindex!(m::Manager, v, ::Type{T}, e::Entity) where {T<:ComponentData}
		entity_assert(m, e)
		return m[T][id(e)] = v
	end

	function Base.setindex!(m::Manager, v, ::Type{T}, es::Vector{Entity}) where {T<:ComponentData}
		comp = m[T]
		for e in es
			entity_assert(m, e)
			comp[id(e)] = v
		end
		return v
	end


	function remove_entity!(m::Manager, e::Entity)
		entity_assert(m, e)
		push!(free_entities(m), e)
		entities(m)[id(e)] = Entity(0)
		for c in components(m)
			if has(c, e)
				remove_entity!(c, e)
			end
		end
	end

	function Base.empty!(m::Manager)
		empty!(m.entities)

		for c in values(components(m))
			empty!(c)
		end
	end

	Base.empty!(c::Component) = empty!(c.data)

	Base.getindex(d::Dict, e::Entity) = d[id(e)]
	Base.setindex!(d::Dict, v, e::Entity) = d[id(e)] = v

end
