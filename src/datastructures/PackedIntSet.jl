
#TODO: Batch creation and allocation
mutable struct PackedIntSet{T<:Integer}
	packed ::Vector{T}
	reverse::Vector{TypedPage{T}}
	function PackedIntSet{T}() where {T}
		out = new{T}(T[], TypedPage{T}[])
		return out
	end
end

function PackedIntSet{T}(indices) where {T}
	set = PackedIntSet{T}()
	for i in indices
		push!(set, i)
	end
	return set
end
PackedIntSet(indices::AbstractVector{T}) where {T} = PackedIntSet{T}(indices)
PackedIntSet() = PackedIntSet{Int}()

Base.eltype(::PackedIntSet{T}) where {T} = T

@inline Base.@propagate_inbounds function packed_id(s::PackedIntSet{T}, i) where {T}
	page, offset = page_offset(s, i)
	return s.reverse[page][offset]::T
end

@inline Base.@propagate_inbounds function reverse_id(s::PackedIntSet{T}, i::Integer) where {T}
	return s.packed[i]::T
end

@inline Base.length(s::PackedIntSet) = length(s.packed)

@inline function page_offset(s::PackedIntSet, i)
	page = div(i - 1, length(eltype(s.reverse))) + 1
	return page, (i-1) & (length(eltype(s.reverse))-1) + 1
end

@inline function assure!(s::PackedIntSet{T}, page) where {T}
	if page > length(s.reverse)
		resize!(s.reverse, page - 1)
		p = TypedPage{T}()
		fill!(p, zero(T))
		push!(s.reverse, p)
		return p, true
	elseif !isassigned(s.reverse, page)
		p = TypedPage{T}()
		fill!(p, zero(T))
		@inbounds s.reverse[page] = p 
		return p, true
	end
	return @inbounds s.reverse[page], false
end

@inline function Base.push!(s::PackedIntSet, i)
	page, offset = page_offset(s, i)
	typed_page, newly_created = assure!(s, page)
	if newly_created || typed_page[offset] == 0
		@inbounds typed_page[offset] = length(s) + 1
		push!(s.packed, i)
		return s
	end
	return s
end

@inline function Base.empty!(s::PackedIntSet)
	empty!(s.packed)
	for p in s.reverse
		fill!(p, 0)
	end
	return s
end

@inline function Base.in(i, s::PackedIntSet)
	page, offset = page_offset(s, i)
	isassigned(s.reverse, page) && @inbounds s.reverse[page][offset] != 0
end

@inline function Base.findfirst(i, s::PackedIntSet{T}) where {T<:Integer}
	page, offset = page_offset(s, i)
	if isassigned(s.reverse, page)
		@inbounds id = s.reverse[page][offset]
		return id
	end
	return zero(T)
end

@inline function Base.pop!(s::PackedIntSet)
	id = pop!(s.packed)
	page, offset = page_offset(s, id)
	@inbounds s.reverse[page][offset] = 0
	return id
end

@inline function Base.pop!(s::PackedIntSet, id)
	@boundscheck if !in(id, s)
		throw(BoundsError(s, id))
	end
	@inbounds begin
		packed_endid           = s.packed[end] 
		from_page, from_offset = page_offset(s, id)
		to_page, to_offset     = page_offset(s, packed_endid)

		packed_id                         = s.reverse[from_page][from_offset]
		s.packed[packed_id]               = packed_endid
		s.reverse[to_page][to_offset]     = s.reverse[from_page][from_offset]
		s.reverse[from_page][from_offset] = 0
		pop!(s.packed)
	end
    return id
end

function cleanup!(s::PackedIntSet{T}) where {T}
	isused = x -> isassigned(s.reverse, x) && any(y -> y != 0, s.reverse[x].data)
	indices = eachindex(s.reverse)
	last_page_id = findlast(isused, indices)
	new_pages    = Vector{TypedPage{T}}(undef, last_page_id)
	for i in indices
		if isused(i)
			new_pages[i] = s.reverse[i]
		end
	end
	s.reverse = new_pages
end


Base.iterate(s::PackedIntSet, args...) = iterate(s.packed, args...)

struct ZippedPackedIntSetIterator{I<:Integer,VT,IT}
	valid_sets::VT
	shortest_set::PackedIntSet{I}
	excluded_sets::IT
	function ZippedPackedIntSetIterator(valid_sets::PackedIntSet...;exclude::NTuple{N, PackedIntSet}=()) where{N}
		shortest = valid_sets[findmin(map(x->length(x), valid_sets))[2]]
		new{eltype(shortest), typeof(valid_sets), typeof(exclude)}(valid_sets, shortest, exclude)
	end
end

Base.zip(s::PackedIntSet...;kwargs...) = ZippedPackedIntSetIterator(s...;kwargs...)

@inline Base.length(it::ZippedPackedIntSetIterator) = length(it.shortest_set)

in_excluded(id, it::ZippedPackedIntSetIterator{I,VT,Tuple{}}) where {I,VT} = false

function in_excluded(id, it)
	for e in it.excluded_sets
		if id in e
			return true
		end
	end
	return false
end

@inline function in_valid(id, it)
    for e in it.valid_sets
        if !in(id, e)
            return false
        end
    end
    return true
end

@inline id_tids(it, state) = (id = it.shortest_set.packed[state]; return id, map(x -> findfirst(id, x), it.valid_sets))
#TODO cleanup
Base.@propagate_inbounds function Base.iterate(it::ZippedPackedIntSetIterator, state=1)
    itlen = length(it)
	if state > itlen
		return nothing
	end
	for i in state:itlen
    	@inbounds id = it.shortest_set.packed[i]
    	if in_valid(id, it) && !in_excluded(id, it)
        	return id, i+1
    	end
	end
end

current_id(x::ZippedPackedIntSetIterator) = x.current_id
