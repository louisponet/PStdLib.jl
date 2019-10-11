elements_per_page(::Type{T}) where {T} = 512
struct TypedPage{T}
	data::Vector{T}
	function TypedPage{T}() where {T}
		new{T}(Vector{T}(undef, elements_per_page(T)))
	end
end

Base.fill!(p::TypedPage, v) = (fill!(p.data, v); p)

@inline Base.length(::TypedPage{T}) where {T} = elements_per_page(T)
@inline Base.length(::Type{TypedPage{T}}) where {T} = elements_per_page(T)

@inline Base.checkbounds(p::TypedPage{T}, i::Integer) where {T} =
	i > length(p) && throw(BoundsError(p, i))

@inline Base.@propagate_inbounds function Base.getindex(p::TypedPage, i::Integer)
	@boundscheck checkbounds(p, i)
	return @inbounds p.data[i]
end

@inline Base.@propagate_inbounds function Base.setindex!(p::TypedPage, v, i::Integer)
	@boundscheck checkbounds(p, i)
	return @inbounds p.data[i] = v
end
