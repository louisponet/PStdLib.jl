struct PackedIntSet{T<:Integer,P<:TypedPage{T}}
	packed ::Vector{T}
	reverse::Vector{P}
	function PackedIntSet{T,P}() where {T,P}
		out = new{T,P}(T[], P[])
		return out
	end
end

@generated function PackedIntSet{T}() where {T}
	pagesize = ccall(:jl_getpagesize, Clong, ())
	quote
		nmax = div($pagesize, sizeof(T))
		return PackedIntSet{T, TypedPage{T, nmax}}()
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

@inline Base.length(s::PackedIntSet) = length(s.packed)

@inline function page_offset(s::PackedIntSet{T,P}, i) where {T,P}
	page = div(i - 1, length(P)) + 1
	return page, mod1(i, length(P))
end

@inline function assure!(s::PackedIntSet{T, P}, page) where {T,P}
	if page > length(s.reverse)
		resize!(s.reverse, page - 1)
		p = P()
		fill!(p, zero(T))
		push!(s.reverse, p)
		return p, true
	elseif !isassigned(s.reverse, page)
		p = P()
		fill!(p, zero(T))
		s.reverse[page] = p 
		return p, true
	end
	return s.reverse[page], false
end

@inline function Base.push!(s::PackedIntSet{T, P}, i) where {T,P}
	page, offset = page_offset(s, i)
	typed_page, newly_created = assure!(s, page)
	if newly_created || typed_page[offset] == 0
		@inbounds typed_page[offset] = length(s) + 1
		push!(s.packed, i)
		return s
	end
	return s
end

@inline function Base.empty!(s::PackedIntSet{T}) where {T}
	empty!(s.packed)
	for p in s.reverse
		fill!(p, zero(T))
	end
	return s
end

@inline function Base.in(i, s::PackedIntSet)
	page, offset = page_offset(s, i)
	isassigned(s.reverse, page) &&  s.reverse[page][offset] != 0
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
	packed_endid           = s.packed[end] 
	from_page, from_offset = page_offset(s, id)
	to_page, to_offset     = page_offset(s, packed_endid)

	packed_id                         = s.reverse[from_page][from_offset]
	s.packed[packed_id]               = packed_endid
	s.reverse[to_page][to_offset]     = s.reverse[from_page][from_offset]
	s.reverse[from_page][from_offset] = 0
	pop!(s.packed)
    return id
end

