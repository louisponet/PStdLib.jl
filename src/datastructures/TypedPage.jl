elements_per_page(::Type{T}) where {T} = div(PAGESIZE, sizeof(T))
struct TypedPage{T}
	data::Vector{T}
	function TypedPage{T}() where {T}
		new{T}(Vector{T}(undef, elements_per_page(T)))
	end
end

Base.fill!(p::TypedPage, v) = (fill!(p.data, v); p)

Base.length(::TypedPage{T}) where {T} = elements_per_page(T)
Base.length(::Type{TypedPage{T}}) where {T} = elements_per_page(T)

@inline Base.@propagate_inbounds function Base.getindex(p::TypedPage, i)
	@boundscheck if i > length(p)
		throw(BoundsError(p, i))
	end
	return p.data[i]
end

@inline Base.@propagate_inbounds function Base.setindex!(p::TypedPage, v, i)
	@boundscheck if i > length(p)
		throw(BoundsError(p, i))
	end
	return p.data[i] = v
end
