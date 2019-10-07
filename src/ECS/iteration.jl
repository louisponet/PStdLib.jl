Entity(x::PDataStructures.ZippedLooseIterator) = Entity(PDataStructures.current_id(x))

Base.@propagate_inbounds Base.iterate(c::Component, args...) = iterate(data(c), args...) 

struct EntityIterator{C<:AbstractComponent}
	component::C
end

Base.@propagate_inbounds function Base.iterate(e::EntityIterator, state=1)
	n = iterate(e.component, state)
	n === nothing && return n
	(Entity(e.component, state), n[1]), n[2]
end

@inline iterfunc(c::Enumerate{<:AbstractComponent}, i::Integer) = iterate(c, (i,i))
@inline iterfunc(c::AbstractComponent, i::Integer) = iterate(c, i)

function (::Type{T})(comps::EnumUnion{AbstractComponent}...;  exclude = ()) where {T<:PDataStructures.AbstractZippedLooseIterator}
	iterator = DataStructures.ZippedSparseIntSetIterator(map(x -> indices(x), comps)...; exclude=map(x->indices(x), exclude))
	T(comps, iterator, 0)
end

Base.zip(cs::EnumUnion{AbstractComponent}...;kwargs...) = PDataStructures.ZippedLooseIterator(cs...;kwargs...)

Base.@propagate_inbounds function Base.iterate(c::SharedComponent, state=1)
	state > length(c) && return nothing
	return c[state], state+1
end

function Base.iterate(e::Enumerate{<:SharedComponent}, state=(1,))
	n = iterate(storage(e.itr), state[1])
	n === nothing && return n
	return (state[1], shared_data(e.itr)[n[1]]), Base.tail(n)
end

