mutable struct LooseVector{T,PS<:PackedIntSet{Int}} <: AbstractVector{T}
	indices::PS
	data   ::Vector{T}
	function LooseVector{T}(values::AbstractVector{T}) where {T}
		set = PackedIntSet{Int}(1:length(values))
		return new{T, typeof(set)}(set, values)
	end
end

LooseVector{T}() where {T} = LooseVector{T}(T[])

@inline packed_id(s::LooseVector, i) = packed_id(s.indices, i)

@inline Base.length(s::LooseVector) = length(s.data)
@inline Base.size(s::LooseVector) = (length(s),)

Base.IndexStyle(::Type{<:LooseVector}) = IndexLinear()

function Base.iterate(s::LooseVector, state=1)
	if state > length(s)
		return nothing
	else
		return @inbounds s.data[state], state + 1
	end
end

@inline Base.in(i, s::LooseVector) = in(i, s.indices)

@inline function Base.setindex!(s::LooseVector, v, i)
	if !in(i, s)
		push!(s.indices, i)
		push!(s.data, v)
	else
		@inbounds s.data[packed_id(s, i)] = v
	end
	return v
end

@inline function Base.getindex(s::LooseVector, i)
	@boundscheck if !in(i, s)
		throw(BoundsError(s, i))
	end
	return s.data[packed_id(s, i)]
end

@inline function Base.pop!(s::LooseVector, i)
	@boundscheck if !in(i, s)
		throw(BoundsError(s, i))
	end
	n = length(s)
	@inbounds begin
		id = packed_id(s, i)
		v = s.data[id]
		s.data[id] = s.data[end]
		pop!(s.data)
		pop!(s.indices, i)
	end
	return v
end

@inline function Base.empty!(s::LooseVector)
	empty!(s.data)
	empty!(s.indices)
end

@inline Base.eltype(s::LooseVector{T}) where T = T

@inline Base.isempty(s::LooseVector) = isempty(s.data)

Base.mapreduce(f, op, A::LooseVector; kwargs...) =
	mapreduce(f, op, view(A.data, 1:length(A)); kwargs...) 

struct LooseIterator{T}
	vecs::T
	shortest_vec_length::Int
	shortest_vec_id::Int
	function LooseIterator(vecs::LooseVector...)
		minl  = typemax(Int)
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
		if !in(id, s)
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

	id = it.vecs[it.shortest_vec_id].indices.packed[state]
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
	id = it.vecs[it.shortest_vec_id].indices.packed[state]
	if !all_have_index(id, it.vecs)
		return iterate(e, state)
	end
	return (id, map(x->x[id], it.vecs)), state
end
