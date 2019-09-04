module ECS
	using ..DataStructures
	import ..getfirst
	export System
	export SystemData
	export ComponentData
	export Component
	export Entity
	export Manager

	export update

	const VECTORTYPE = LooseVector
	abstract type AbstractManager end

	struct Entity
		id::Int
	end

	@inline id(e::Entity) = e.id

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

	@inline Base.@propagate_inbounds Base.getindex(v::AbstractVector, e::Entity) = v[id(e)]
	# Base.setindex!(vec::AbstractVector, v, e::Entity) = setindex!(vec, v, id(e))
	# Base.deleteat!(vec::AbstractVector, e::Entity) = deleteat!(vec, id(e))

	abstract type ComponentData end

	abstract type AbstractComponent{T<:ComponentData} end

	const ComponentDict = Dict{Type{<:ComponentData}, AbstractComponent}

	Base.eltype(::AbstractComponent{T}) where T = T
	Base.eltype(::Type{AbstractComponent{T}}) where T = T

	@inline component_data(c::AbstractComponent) = c.data
	@inline Base.in(c::AbstractComponent, e::Entity) = in(id(e), data(c))
	Base.zip(cs::AbstractComponent...) = DataStructures.ZippedLooseIterator(cs...)

	function (::Type{T})(comps::AbstractComponent...) where {T<:DataStructures.AbstractZippedLooseIterator}
		iterator = DataStructures.ZippedPackedIntSetIterator(map(x -> component_data(x).indices, comps)...)
		T(comps, iterator)
	end


	"""
	The most basic component type.
	Holds a `PackedIntSet` that represents whether an entity has the component, and a data vector that
	has the component_datas contiguously stored in memory in the same order as the entities indices inside
	the `PackedIntSet` (e.g. without any sorting or popping, the order in which the component was added
	to the entities).

	Indexing into a component with an `Entity` will return the component_data linked to that entity,
	indexing with a regular Int will return directly the `ComponentData` that is stored in the data
	vector at that index, i.e. generally not the component_data linked to the `Entity` with that `Int` as id.
	"""
	struct Component{T} <: AbstractComponent{T}
		id  ::Int
		data::VECTORTYPE{T}
		function Component{T}(m::AbstractManager) where {T<:ComponentData}
			n = length(components(m)) + 1
			v = VECTORTYPE{T}()
			c = new{T}(n, v)
			register!(m, c)
			return c
		end
	end

	@inline Base.@propagate_inbounds Base.getindex(c::Component, e::Entity) = component_data(c)[id(e)]
	@inline Base.@propagate_inbounds Base.getindex(c::Component, e::Int)    = component_data(c).data[e]

	@inline Base.@propagate_inbounds Base.pointer(c::Component, e::Entity) = pointer(component_data(c), id(e))
	@inline Base.pointer(c::Component, e::Int) = DataStructures.packed_pointer(c.data, e)

	@inline Base.@propagate_inbounds Base.setindex!(c::Component, v, e::Entity) = component_data(c)[id(e)] = v
	@inline Base.@propagate_inbounds Base.setindex!(c::Component, v, e::Int) = component_data(c).data[e] = v

	@inline Base.empty!(c::Component) = empty!(component_data(c))
	Base.iterate(c::Component, args...) = iterate(component_data(c), args...)

	Base.zip(cs::Component...) = zip(component_data.(cs)...)

	DataStructures.pointer_zip(cs::Component...) =
		pointer_zip(component_data.(cs)...)

	DataStructures.pointer_zip(cs::AbstractComponent...) =
		DataStructures.PointerZippedLooseIterator(cs...)

	#maybe this shouldn't be called remove_entity!
	remove_entity!(c::AbstractComponent, e::Entity) =
		pop!(component_data(c), id(e))


	"""
	Similar to a normal `Component` however the data that is locked to the underlying `PackedIntSet`
	is now the indices into the vector with shared component_data.

	Indexing is similar to the normal `Component` however indexing with an `Int` now returns the shared data
	at that index.
	"""
	struct SharedComponent{T<:ComponentData} <: AbstractComponent{T}
		id    ::Int
		data  ::VECTORTYPE{Int} #These are basically the ids
		shared::Vector{T}
		function SharedComponent{T}(m::AbstractManager) where {T<:ComponentData}
			n = length(components(m)) + 1
			v = VECTORTYPE{Int}()
			c = new{T}(n, v, T[])
			register!(m, c)
			return c
		end
	end

	@inline shared_data(c::SharedComponent) = c.shared

	@inline Base.@propagate_inbounds Base.getindex(c::SharedComponent, e::Int) =
		shared_data(c)[component_data(c).data[e]]

	@inline Base.@propagate_inbounds function Base.getindex(c::SharedComponent, e::Entity)
		index = component_data(c)[id(e)]
		return shared_data(c)[index]
	end

	@inline Base.@propagate_inbounds Base.pointer(c::SharedComponent, e::Entity) =
			pointer(shared_data(c), component_data(c)[id(e)])

	@inline Base.pointer(c::SharedComponent, e::Int) = pointer(shared_data(c), component_data(c).data[e])

	@inline Base.@propagate_inbounds function Base.setindex!(c::SharedComponent, v, e::Entity)
		sd = shared_data(c)
		datid = findfirst(x -> x === v, sd)
		if datid === nothing
			push!(sd, v)
			component_data(c)[id(e)] = length(sd)
		else
			component_data(c)[id(e)] = datid
		end
	end

	@inline Base.@propagate_inbounds Base.setindex!(c::SharedComponent, v, e::Int) =
		shared_data(c)[component_data(c).data[e]] = v

	@inline Base.empty!(c::SharedComponent) = (empty!(c.data); empty!(c.shared))

	Base.iterate(c::SharedComponent, args...) = iterate(c.shared, args...)

	abstract type System end

	data(s::System) =
		s.data

	isengaged(s::System) = data(s).engaged
	engage!(s::System)   = data(s).engaged = true
	disengage!(s::System)= data(s).engaged = false

	requested_components(s::System) = data(s).requested_components

	Base.getindex(s::System, ::Type{T}) where {T<:ComponentData} = 
		data(s)[T]

	function register!(s::System, c::AbstractComponent{T}) where {T}
		req_comps = requested_components(s)
		id = findfirst(x -> x<:T, req_comps)
		if id !== nothing
			pop!(req_comps, id)
		end
		new_comps = (data(s).components..., c)
		engaged = isempty(req_comps) ? true : false
		s.data = SystemData(engaged, new_comps, req_comps)
	end


	#Each system should have this as it's data field, or data() needs to be
	#overloaded
	#TODO: Speedup: maybe using Tuples of components might be better,
	#               since technically one should know what components to use.
	struct SystemData{T<:Tuple}
		engaged::Bool 
		#These are the components that the system will work with
		components::T
		requested_components::Vector{Type{ComponentData}}
	end

	@generated function Base.getindex(s::SystemData{CT}, ::Type{T}) where {CT,T<:ComponentData}
		id = findfirst(x-> x<:AbstractComponent{T}, CT.parameters)
		quote
			return s.components[$id]
		end
	end

	struct Manager <: AbstractManager
		entities     ::Vector{Entity}
		free_entities::Vector{Entity}
		components   ::ComponentDict
		systems      ::Vector{System}
	end
	Manager() = Manager(Entity[], Entity[], ComponentDict(), System[])

	function Manager(components::Type{<:ComponentData}...)
		m = Manager()
		comps = ComponentDict()
		for c in components
			comps[c] = Component{c}(m)
		end
		return m
	end

	function Manager(components::T, shared_components::T) where {T<:Union{NTuple{N,DataType} where N,AbstractVector{DataType}}}
		m = Manager()
		comps = ComponentDict()
		for c in components
			comps[c] = Component{c}(m)
		end
		for c in shared_components
			comps[c] = SharedComponent{c}(m)
		end
		return m
	end

	Base.map(f, s::Union{System, Manager}, T...) = f(map(x -> getindex(s, x), T)...)

	function SystemData(component_types::NTuple, manager::Manager, engaged=true)
		comps = AbstractComponent[]
		requested_components = Type{ComponentData}[]
		for ct in component_types
			if ct ∈ keys(components(manager))
				push!(comps, manager[ct])
			else
				push!(requested_components, ct)
			end
		end
		ct = (comps...,)
		engaged = isempty(requested_components) && engaged
		return SystemData{typeof(ct)}(engaged, ct, requested_components)
	end


	components(m::Manager)     = m.components
	entities(m::Manager)       = m.entities
	free_entities(m::Manager)  = m.free_entities
	valid_entities(m::Manager) = filter(x -> x.id != 0, m.entities)
	systems(m::Manager)        = m.systems

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

	Entity(m::Manager, i::Int) = i <= length(m.entities) ? m.entities[i] : Entity(m)

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

	Base.getindex(d::Dict, e::Entity) = d[id(e)]
	Base.setindex!(d::Dict, v, e::Entity) = d[id(e)] = v

	function register!(m::Manager, c::AbstractComponent{T}) where {T}
		map(x -> register!(x, c), systems(m))
		components(m)[T] = c
	end
end
