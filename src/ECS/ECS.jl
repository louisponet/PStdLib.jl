module ECS
	using ..DataStructures
	import ..DataStructures: indices, data, iterfunc
	using ..DataStructures: Direct, Reverse
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

	@inline in(c::AbstractComponent, e::Entity) = in(id(e), storage(c))


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
		id  ::Int
		storage::VECTORTYPE{T}
		function Component{T}(m::AbstractManager) where {T<:ComponentData}
			n = length(components(m)) + 1
			v = VECTORTYPE{T}()
			c = new{T}(n, v)
			register!(m, c)
			return c
		end
	end
	eltype(::Type{Component{T}}) where T = T

	@inline @propagate_inbounds getindex(c::Component, e::Entity) = storage(c)[id(e), Reverse()]
	@inline @propagate_inbounds getindex(c::Component, e::Int)    = storage(c)[e, Direct()]

	@inline @propagate_inbounds pointer(c::Component, e::Entity) = pointer(storage(c), id(e), Reverse())
	@inline pointer(c::Component, e::Int) = pointer(storage(c), e, Direct())

	@inline @propagate_inbounds setindex!(c::Component, v, e::Entity) = storage(c)[id(e), Reverse()] = v
	@inline @propagate_inbounds setindex!(c::Component, v, e::Int) = storage(c)[e, Direct()] = v

	@inline empty!(c::Component) = empty!(storage(c))

	DataStructures.pointer_zip(cs::Component...) =
		pointer_zip(storage.(cs)...)

	DataStructures.pointer_zip(cs::AbstractComponent...) =
		DataStructures.PointerZippedLooseIterator(cs...)

	#maybe this shouldn't be called remove_entity!
	remove_entity!(c::AbstractComponent, e::Entity) =
		pop!(storage(c), id(e))


	"""
	Similar to a normal `Component` however the data that is locked to the underlying `PackedIntSet`
	is now the indices into the vector with shared storage.

	Indexing is similar to the normal `Component` however indexing with an `Int` now returns the shared data
	at that index.
	"""
	struct SharedComponent{T<:ComponentData} <: AbstractComponent{T}
		id    ::Int
		storage::VECTORTYPE{Int} #These are basically the ids
		shared::Vector{T}
		function SharedComponent{T}(m::AbstractManager) where {T<:ComponentData}
			n = length(components(m)) + 1
			v = VECTORTYPE{Int}()
			c = new{T}(n, v, T[])
			register!(m, c)
			return c
		end
	end

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
		datid = findfirst(x -> x === v, sd)
		if datid === nothing
			push!(sd, v)
			storage(c)[id(e)] = length(sd)
		else
			storage(c)[id(e)] = datid
		end
	end

	@inline @propagate_inbounds setindex!(c::SharedComponent, v, e::Int) =
		shared_data(c)[storage(c).data[e]] = v

	@inline empty!(c::SharedComponent) = (empty!(c.data); empty!(c.shared))

	abstract type System end

	requested_components(::Type{System}) = ()

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
		components(m)[T]

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
		if !haskey(m.components, T)
			c = Component{T}(m)
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

		for c in values(components(m))
			empty!(c)
		end
	end

	function register!(m::AbstractManager, c::AbstractComponent{T}) where {T}
		components(m)[T] = c
	end

	function update_systems(m::AbstractManager)
		for sys in systems(m)
			req_components = requested_components(sys)
			if all(x -> x ∈ keys(components(m)), req_components)
				sys(map(x -> m[x], requested_components(sys))...)
			end
		end
	end

	has_component(m::AbstractManager, ::Type{R}) where {R<:ComponentData} = haskey(components(m), R)

	function add_requested_components(m::AbstractManager, s::System)
		for r in requested_components(s)
			if !has_component(m, r)
				Component{r}(m)
			end
		end
	end
	add_requested_components(m::AbstractManager) = map(x->add_requested_components(m, x), systems(m))

	function prepare(m::AbstractManager)
		for s in systems(m)
			add_requested_components(m, s)
			prepare(s, m)
		end
	end

	prepare(::System, ::AbstractManager) = nothing
	include("iteration.jl")
end
