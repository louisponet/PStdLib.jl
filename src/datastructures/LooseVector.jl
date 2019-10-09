import Base.Enumerate

mutable struct LooseVector{T} <: AbstractVector{T}
	indices::PackedIntSet{Int}
	data   ::Vector{T}
	function LooseVector{T}(values::AbstractVector{T}) where {T}
		set = PackedIntSet{Int}(1:length(values))
		return new{T}(set, values)
	end
end

LooseVector{T}() where {T} = LooseVector{T}(T[])

@inline data(s::LooseVector)    = s.data
@inline indices(s::LooseVector) = s.indices

@inline data(s::Enumerate{<:LooseVector}) = enumerate(s.itr.data)
@inline indices(s::Enumerate{<:LooseVector}) = s.itr.indices

@inline packed_id(s::LooseVector, i) = packed_id(s.indices, i)

@inline reverse_id(s::LooseVector, i) = reverse_id(s.indices, i)

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

struct Direct  end
struct Reverse end

@inline Base.setindex!(s::LooseVector, v, i, ::Direct) = setindex!(data(s), v, i)

@inline function Base.setindex!(s::LooseVector, v, i, ::Reverse)
	if !in(i, s)
		push!(s.indices, i)
		push!(s.data, v)
	else
		@inbounds s.data[packed_id(s, i)] = v
	end
	return v
end
@inline Base.setindex!(s::LooseVector, v, i) = setindex!(s, v, i, Reverse()) 

@inline function Base.getindex(s::LooseVector, i, ::Reverse)
	@boundscheck if !in(i, s)
		throw(BoundsError(s, i))
	end
	return @inbounds data(s)[packed_id(s, i)]
end
@inline Base.getindex(s::LooseVector, i) = getindex(s, i, Reverse())

@inline Base.getindex(s::LooseVector, i, ::Direct) = getindex(data(s), i)

Base.@propagate_inbounds Base.pointer(s::LooseVector, i::Integer, ::Direct) =
	pointer(data(s), i)

Base.@propagate_inbounds Base.pointer(s::LooseVector, i::Integer, ::Reverse) =
	pointer(data(s), packed_id(i))

Base.@propagate_inbounds Base.pointer(s::LooseVector, i::Integer) = pointer(s, i, Reverse())


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
