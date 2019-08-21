
#TODO: Batch creation and allocation
struct PackedIntSet{T<:Integer}
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

@inline Base.@propagate_inbounds function packed_id(s::PackedIntSet{T}, i) where {T}
	page, offset = page_offset(s, i)
	return s.reverse[page][offset]::T
end

@inline Base.length(s::PackedIntSet) = length(s.packed)

@inline function page_offset(s::PackedIntSet, i)
	page = div(i - 1, length(eltype(s.reverse))) + 1
	return page, mod1(i, length(eltype(s.reverse)))
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
		s.reverse[page] = p 
		return p, true
	end
	return s.reverse[page], false
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
	isassigned(s.reverse, page) && s.reverse[page][offset] != 0
end

@inline function Base.pop!(s::PackedIntSet)
	id = pop!(s.packed)
	page, offset = page_offset(s, id)
	s.reverse[page][offset] = 0
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

