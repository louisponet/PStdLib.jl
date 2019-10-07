module ECS
	using ..PDataStructures
	import ..PDataStructures: indices, data, iterfunc
	using ..PDataStructures: Direct, Reverse
	using Base: Enumerate, @propagate_inbounds
	import Base: getindex, setindex!, iterate, eltype, in, isempty, length,
				 pointer, empty!, push!, insert!, deleteat!
	using InlineExports
	import ..getfirst
	import Base: == 

	export System
	export SystemData
	export ComponentData
	export Component
	export Entity
	export Manager
	export manager
	export insert_system, push_system

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
		push!(entities(m), e)
		return e
	end

	@inline @propagate_inbounds getindex(v::AbstractVector, e::Entity) = v[id(e)]
	# setindex!(vec::AbstractVector, v, e::Entity) = setindex!(vec, v, id(e))
	# Base.deleteat!(vec::AbstractVector, e::Entity) = deleteat!(vec, id(e))

	abstract type ComponentData end

	function Entity(m::AbstractManager, datas::ComponentData...)
		e = Entity(m)
		for d in datas
			m[typeof(d), e] = d
		end
		return e
	end

	#TODO improve this
	==(c1::T, c2::T) where {T <: ComponentData} =
		all(getfield.((c1,), fieldnames(T)) .== getfield.((c2,), fieldnames(T)))

	abstract type AbstractComponent{T<:ComponentData} end

	Entity(c::AbstractComponent, i::Integer) = Entity(DataStructures.reverse_id(storage(c).indices,i))

	#TODO use heterogenous storage maybe
	const ComponentDict = Dict{Type{<:ComponentData}, AbstractComponent}

	eltype(::AbstractComponent{T}) where T = T
	datatype(c::AbstractComponent) = eltype(c)

	@generated function getindex(t::C, ::Type{T}) where {C<:Tuple,T<:ComponentData}
		id = findfirst(x -> eltype(x)==T, C.parameters)
		return :(t[$id])
	end

	const EnumUnion{T} = Union{T, Enumerate{<:T}}

	@inline storage(c::AbstractComponent) = c.storage
	@inline storage(c::Enumerate{<:AbstractComponent}) = storage(c.itr)

	@inline indices(c::EnumUnion{AbstractComponent}) = indices(storage(c))
	@inline data(c::AbstractComponent)    = data(storage(c))
	@inline data(c::Enumerate{<:AbstractComponent})    = enumerate(data(storage(c)))

	@inline in(e::Entity, c::AbstractComponent) = in(id(e), storage(c))


	isempty(c::AbstractComponent) = isempty(storage(c))

	length(c::AbstractComponent) = length(storage(c))

	"""
	The most basic component type.
	Holds a `PackedIntSet` that represents whether an entity has the component, and a data vector that
	has the storages contiguously stored in memory in the same order as the entities indices inside
	the `PackedIntSet` (e.g. without any sorting or popping, the order in which the component was added
	to the entities).

	Indexing into a component with an `Entity` will return the storage linked to that entity,
	indexing with a regular Int will return directly the `ComponentData` that is stored in the data
	vector at that index, i.e. generally not the storage linked to the `Entity` with that `Int` as id.
	"""
	struct Component{T} <: AbstractComponent{T}
		storage::VECTORTYPE{T}
	end
	Component{T}() where {T<:ComponentData} = Component{T}(VECTORTYPE{T}())
	Component(::Type{T}) where {T<:ComponentData} = Component{T}()

	eltype(::Type{Component{T}}) where T = T

	@inline @propagate_inbounds getindex(c::Component, e::Entity) = storage(c)[id(e), Reverse()]
	@inline @propagate_inbounds getindex(c::Component, e::Int)    = storage(c)[e, Direct()]

	@inline @propagate_inbounds pointer(c::Component, e::Entity) = pointer(storage(c), id(e), Reverse())
	@inline pointer(c::Component, e::Int) = pointer(storage(c), e, Direct())

	@inline @propagate_inbounds setindex!(c::Component, v, e::Entity) = storage(c)[id(e), Reverse()] = v
	@inline @propagate_inbounds setindex!(c::Component, v, e::Int) = storage(c)[e, Direct()] = v

	@inline empty!(c::Component) = empty!(storage(c))

	PDataStructures.pointer_zip(cs::Component...) =
		pointer_zip(storage.(cs)...)

	PDataStructures.pointer_zip(cs::AbstractComponent...) =
		PDataStructures.PointerZippedLooseIterator(cs...)

	#maybe this shouldn't be called remove_entity!
	pop!(c::AbstractComponent, e::Entity) =
		pop!(storage(c), id(e))

	preferred_component_type(::Type{<:ComponentData}) = Component


	"""
	Similar to a normal `Component` however the data that is locked to the underlying `PackedIntSet`
	is now the indices into the vector with shared storage.

	Indexing is similar to the normal `Component` however indexing with an `Int` now returns the shared data
	at that index.
	"""
	struct SharedComponent{T<:ComponentData} <: AbstractComponent{T}
		storage::VECTORTYPE{Int} #These are basically the ids
		shared::Vector{T}
	end
	SharedComponent{T}() where {T<:ComponentData} = SharedComponent{T}(VECTORTYPE{Int}(), T[])

	eltype(::Type{SharedComponent{T}}) where T = T

	@inline shared_data(c::SharedComponent) = c.shared

	@inline @propagate_inbounds getindex(c::SharedComponent, e::Int) =
		shared_data(c)[storage(c)[e, Direct()]]

	@inline @propagate_inbounds function getindex(c::SharedComponent, e::Entity)
		index = storage(c)[id(e), Reverse()]
		return shared_data(c)[index]
	end

	@inline @propagate_inbounds pointer(c::SharedComponent, e::Entity) =
			pointer(shared_data(c), storage(c)[id(e)])

	@inline pointer(c::SharedComponent, e::Int) = pointer(shared_data(c), storage(c)[e, Direct()])

	@inline @propagate_inbounds function setindex!(c::SharedComponent, v, e::Entity)
		sd = shared_data(c)
		datid = findfirst(x -> x == v, sd)
		if datid === nothing
			push!(sd, v)
			storage(c)[id(e)] = length(sd)
		else
			storage(c)[id(e)] = datid
		end
	end

	@inline @propagate_inbounds setindex!(c::SharedComponent, v, e::Int) =
		shared_data(c)[storage(c).data[e]] = v

	@inline empty!(c::SharedComponent) = (empty!(storage(c)); empty!(c.shared))

	abstract type System end

	update(::S, m::AbstractManager) where {S<:System}= error("No update method implemented for $S")

	requested_components(::System) = ()

	mutable struct Manager <: AbstractManager
		entities     ::Vector{Entity}
		free_entities::Vector{Entity}
		components   ::Dict{DataType, Union{Component,SharedComponent}}
		systems      ::Vector{System}
	end
	Manager() = Manager(Entity[], Entity[], (), System[])

	# Manager(cs::AbstractComponent...) = Manager(Entity[], Entity[], cs, System[])
	Manager(cs::AbstractComponent...) = Manager(Entity[], Entity[], Dict([eltype(x) => x for x in cs]), System[])
	Manager(components::Type{<:ComponentData}...) = Manager(map(x->preferred_component_type(x){x}(), components)...)

	function Manager(components::T, shared_components::T) where {T<:Union{NTuple{N,DataType} where N,AbstractVector{DataType}}}
		comps = AbstractComponent[]
		for c in components
			push!(comps, Component{c}())
		end
		for c in shared_components
			push!(comps, SharedComponent{c}())
		end
		return Manager(comps...)
	end

	function Manager(systems::System...)
		comps = Type{<:ComponentData}[] 
		for s in systems
			for c in requested_components(s)
				push!(comps, c)
			end
		end
		m = Manager(comps...)
		for s in systems
			push!(m.systems, s)
		end
		return m
	end

	Base.map(f, s::Union{System, Manager}, T...) = f(map(x -> getindex(s, x), T)...)

	manager(m::Manager) = m

	@export components(m::AbstractManager)     = manager(m).components
	@export entities(m::AbstractManager)       = manager(m).entities
	@export free_entities(m::AbstractManager)  = manager(m).free_entities
	@export valid_entities(m::AbstractManager) = filter(x -> x.id != 0, entities(m))
	@export systems(m::AbstractManager)        = manager(m).systems

	function all_components(::Type{T}, manager::AbstractManager) where {T<:ComponentData}
		comps = AbstractComponent[]
		for c in components(manager)
			if eltype(c) <: T
				push!(comps, c)
			end
		end
		return comps
	end

	function entity_assert(m::AbstractManager, e::Entity)
		es = entities(m)
		@assert length(es) >= e.id "$e was never initiated."
		@assert es[e] != Entity(0) "$e was removed previously."
	end

	getindex(m::AbstractManager, ::Type{T}) where {T<:ComponentData} =
		components(m)[T]::preferred_component_type(T){T}

	function getindex(m::AbstractManager, e::Entity)
		entity_assert(m, e)		
		data = ComponentData[]
		for c in components(m)
			if has(c, e)
				push!(data, c[e])
			end
		end
		return data
	end

	getindex(m::AbstractManager, args...) = getindex(manager(m), args...)
	setindex!(m::AbstractManager, args...) = setindex!(manager(m), args...)

	#TODO: Performance
	function getindex(m::Manager, ::Type{T}, e::Entity) where {T<:ComponentData}
		entity_assert(m, e)
		return m[T][id(e)]
	end

	function setindex!(m::Manager, v, ::Type{T}, e::Entity) where {T<:ComponentData}
		entity_assert(m, e)
		if !in(T, m)
			c = preferred_component_type(T){T}()
		else
			c = m[T]
		end

		return c[e] = v
	end

	function setindex!(m::Manager, v, ::Type{T}, es::Vector{Entity}) where {T<:ComponentData}
		comp = m[T]
		for e in es
			entity_assert(m, e)
			comp[e] = v
		end
		return v
	end

	push!(m::AbstractManager, sys::System) = push!(systems(m), sys)
	insert!(m::AbstractManager, i::Int, sys::System) = insert!(systems(m), i, sys)

	function insert!(m::AbstractManager, ::Type{T}, sys::System, after=true) where {T<:System}
		id = findfirst(x -> isa(x, T), systems(m))
		if id != nothing
			if after
				insert!(m, id + 1, sys)
			else
				insert!(m, id - 1, sys)
			end
		end
	end

	function Base.deleteat!(m::AbstractManager, ::Type{T}) where {T<:System}
		sysids = findall(x -> isa(x, T), systems(m))
		deleteat!(systems(m), sysids)
	end

	Entity(m::AbstractManager, i::Int) = i <= length(m.entities) ? m.entities[i] : Entity(m)

	function remove_entity!(m::AbstractManager, e::Entity)
		entity_assert(m, e)
		push!(free_entities(m), e)
		entities(m)[id(e)] = Entity(0)
		for c in components(m)
			if has(c, e)
				remove_entity!(c, e)
			end
		end
	end

	function empty!(m::AbstractManager)
		empty!(entities(m))

		for (k, c) in components(m)
			empty!(c)
		end
	end

	function register!(m::AbstractManager, c::AbstractComponent{T}) where {T}
		components(m)[T] = c
	end

	function update_systems(m::AbstractManager)
		for sys in systems(m)
			update(sys, m)
		end
	end

	Base.in(::Type{R}, m::AbstractManager) where {R<:ComponentData} =
		haskey(components(m), R)

	function prepare(m::AbstractManager)
		for s in systems(m)
			prepare(s, m)
		end
	end

	prepare(::System, ::AbstractManager) = nothing

	function generate_component_tuple(m::Manager, s::System)
		current_components = components(m)
		extra_components = []
		for c in requested_components(s)
			if !in(c, m)
				push!(extra_components, preferred_component_type(c)(c))
			end
		end
		return (current_components..., extra_components...)
	end

	function push_system(m::Manager, s::System)
		current_systems = systems(m)
		push!(current_systems, s)
		return Manager(entities(m), free_entities(m), generate_component_tuple(m, s), current_systems)
	end

	function insert_system(m::Manager, id::Integer, s::System)
		current_systems = systems(m)
		insert!(current_systems, id, s)
		return Manager(entities(m), free_entities(m), generate_component_tuple(m, s), current_systems)
	end

	include("iteration.jl")
end
