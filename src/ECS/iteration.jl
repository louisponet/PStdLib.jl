Base.@propagate_inbounds Base.iterate(c::Component, args...) = iterate(data(c), args...) 

struct EntityIterator{C}
	index_iterator::C
end

Base.@propagate_inbounds function Base.iterate(e::EntityIterator, state=1)
	n = iterate(e.index_iterator, state)
	n === nothing && return n
	Entity(n[1]), n[2]
end

entities(comp::AbstractComponent) = 
    EntityIterator(indices(comp))

entities(comps::AbstractComponent...; exclude=()) = 
    EntityIterator(DataStructures.ZippedPackedIntSetIterator(map(x -> indices(x), comps)...; exclude=map(x->indices(x), exclude)))
