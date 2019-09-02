mutable struct LooseVector{T} <: AbstractVector{T}
	indices::PackedIntSet{Int}
	data   ::Vector{T}
	function LooseVector{T}(values::AbstractVector{T}) where {T}
		set = PackedIntSet{Int}(1:length(values))
		return new{T}(set, values)
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
	return @inbounds s.data[packed_id(s, i)]
end

Base.@propagate_inbounds Base.pointer(s::LooseVector, i) = pointer(s.data, s.indices[i])

packed_pointer(s::LooseVector, i) = pointer(s.packed, i)

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

struct ZippedLooseIterator{T, ZI<:ZippedPackedIntSetIterator}
	datas::T
	set_iterator::ZI
	function ZippedLooseIterator(vecs::LooseVector...)
		iterator = ZippedPackedIntSetIterator(map(x -> x.indices, vecs)...)
		datas    = map(x -> x.data, vecs)
		new{typeof(datas), typeof(iterator)}(datas, iterator)
	end
end

Base.zip(s::LooseVector...) = ZippedLooseIterator(s...)

Base.length(it::ZippedLooseIterator) = length(it.set_iterator)

Base.@propagate_inbounds function Base.iterate(it::ZippedLooseIterator, state=1)
	n = iterate(it.set_iterator, state)
	n === nothing && return n
	map((x, y) -> (x, y[x]), n[1], it.datas), n[2]
end




