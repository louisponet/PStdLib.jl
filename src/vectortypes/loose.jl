const DEFAULT_NMAX = 1000
mutable struct LooseVector{T} <: AbstractVector{T}
	n     ::UInt
	nmax  ::UInt
	packed::Vector{UInt}
	loose ::Vector{UInt}
	data  ::Vector{T}
	function LooseVector{T}(nmax=DEFAULT_NMAX) where {T}
		return new{T}(1, nmax, Vector{UInt}(undef, nmax), Vector{UInt}(undef, nmax), Vector{T}(undef, nmax))
	end
end

@inline Base.length(s::LooseVector) = s.n - 1
@inline Base.size(s::LooseVector) = (length(s),)

Base.IndexStyle(::Type{<:LooseVector}) = IndexLinear()

function Base.iterate(s::LooseVector, state=1)
	if state > length(s)
		return nothing
	else
		return @inbounds s.data[state], state + 1
	end
end

@inline extent(s::LooseVector) = s.nmax

@inline packed_id(s::LooseVector, i) =
	unsafe_load(pointer(s.loose, i))

@inline loose_id(s::LooseVector, i) =
	unsafe_load(pointer(s.packed, i))

@inline hasindex(s::LooseVector, i, packedid = packed_id(s,i)) =
	packedid < s.n && loose_id(s, packedid) == i

@inline function Base.setindex!(s::LooseVector, v, i)
	@boundscheck if i > s.nmax
		throw(BoundsError(s, i))
	end
	if !hasindex(s, i)
		@inbounds s.loose[i] = s.n
		@inbounds s.packed[s.n] = i
		s.n += 1
	end
	@inbounds s.data[packed_id(s, i)] = v
end

@inline function Base.getindex(s::LooseVector, i)
	@boundscheck if !hasindex(s, i)
		throw(BoundsError(s, i))
	end
	return s.data[packed_id(s, i)]
end

function Base.deleteat!(s::LooseVector, i)
	@boundscheck if !hasindex(s, i)
		throw(BoundsError(s, i))
	end
	n = length(s)
	@inbounds begin
		id = packed_id(s, i)
		sid = s.packed[n]
		s.packed[n], s.packed[id] = s.packed[id], s.packed[n]
		s.data[n],  s.data[id]  = s.data[id],  s.data[n]
		s.loose[sid] = id
	end
	s.n -= 1
end

@inline Base.empty!(s::LooseVector) = s.n = 1

@inline Base.eltype(s::LooseVector{T}) where T = T

Base.mapreduce(f, op, A::LooseVector; kwargs...) =
	mapreduce(f, op, view(A.data, 1:length(A)); kwargs...) 

struct LooseIterator{T}
	vecs::T
	shortest_vec_length::UInt
	shortest_vec_id::Int
	function LooseIterator(vecs::LooseVector...)
		minl  = typemax(UInt)
		minid = 0
		for (i, s) in enumerate(vecs) 
			if length(s) < minl
				minl = length(s)
				minid = i
			end
		end

		new{typeof(vecs)}(vecs, minl, minid)
	end
end

Base.zip(s::LooseVector...) = LooseIterator(s...)

Base.length(it::LooseIterator) = it.shortest_vec_length

function all_have_index(id, vecs)
	for s in vecs
		if !hasindex(s, id)
			return false
		end
	end
	return true
end

function Base.iterate(it::LooseIterator, state=0)
	state += 1
	if state > length(it)
		return nothing
	end
	id = loose_id(it.vecs[it.shortest_vec_id], state)
	if !all_have_index(id, it.vecs)
		return iterate(it, state)
	end
	return map(x->x[id], it.vecs), state
end

function Base.iterate(e::Base.Enumerate{<:LooseIterator}, state=0)
	state += 1
	it = e.itr
	if state > length(it)
		return nothing
	end
	id = loose_id(it.vecs[it.shortest_vec_id], state)
	if !all_have_index(id, it.vecs)
		return iterate(e, state)
	end
	return (id, map(x->x[id], it.vecs)), state
end
