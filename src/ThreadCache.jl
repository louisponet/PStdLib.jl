module ThreadCaches
	using LinearAlgebra
	using InlineExports

	import Base: +, -, *, /, @propagate_inbounds

	"""
		ThreadCache{T}

	A basic threaded cache that can be used as if it is the original type.
	Mostly focused on arrays.
	"""
	@export struct ThreadCache{T}
		caches::Vector{T}
		ThreadCache(orig::T) where {T} =
			new{T}([deepcopy(orig) for i = 1:nthreads()])
	end

	@inline cache(t::ThreadCache) =
		t.caches[threadid()]

	for f in (:getindex, :setindex!, :copyto!, :size, :length, :iterate, :sum, :view, :fill!)
		@eval @propagate_inbounds @inline Base.$f(t::ThreadCache{<:AbstractArray}, i...) = Base.$f(cache(t), i...)
	end

	for op in (:+, :-, :*, :/)
		@eval @inline $op(t::ThreadCache{T}, v::T) where {T} = $op(cache(t), v)
		@eval @inline $op(v::T, t::ThreadCache{T}) where {T} = $op(v, cache(t))
	end

	@export fillall!(t::ThreadCache{<:AbstractArray{T}}, v::T)   where {T} =
		fill!.(t.caches, (v,))

	@export gather(t::ThreadCache) = sum(t.caches)

	LinearAlgebra.mul!(t1::ThreadCache{T}, v::T, t2::ThreadCache{T}) where {T<:AbstractArray} =
		mul!(cache(t1), v, cache(t2))

	LinearAlgebra.mul!(t1::T, v::T, t2::ThreadCache{T}) where {T<:AbstractArray} =
		mul!(t1, v, cache(t2))

	LinearAlgebra.mul!(t1::ThreadCache{T}, t2::ThreadCache{T}, t3::ThreadCache{T}) where {T<:AbstractArray} =
		mul!(cache(t1), cache(t2), cache(t3))

	LinearAlgebra.adjoint!(t1::ThreadCache{T}, v::T) where {T} =
		adjoint!(cache(t1), v)

	Base.ndims(::Type{ThreadCache{T}}) where {T<:AbstractArray} =
		ndims(T)
	Base.Broadcast.broadcastable(tc::ThreadCache{<:AbstractArray}) =
		cache(tc)
end
