struct TypedPage{T, S}
	data::Vector{T}
	function TypedPage{T, S}() where {T, S}
		new{T, S}(Vector{T}(undef, S))
	end
end

@generated function TypedPage{T}() where {T}
	pagesize = ccall(:jl_getpagesize, Clong, ())
	quote
		nmax = div($pagesize, sizeof(T))
		return TypedPage{T, nmax}()
	end
end

Base.fill!(p::TypedPage, v) = (fill!(p.data, v); p)

Base.length(::TypedPage{T, S}) where {T,S} = S
Base.length(::Type{TypedPage{T, S}}) where {T,S} = S

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
