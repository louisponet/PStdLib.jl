norm2(a::AbstractArray) =
	dot(a, a)

Base.zeros(a::AbstractArray{T}) where T =
	fill!(similar(a), zero(T))

"""
Like `filter()[1]`.
"""
function getfirst(f::Function, A)
    for el in A
        if f(el)
            return el
        end
    end
end

"""
	separate!(f::Function, B::T, A::T) where T

Like `separate` but a vector `B` can be given in which the result will be stored.
"""
function separate!(f::Function, B::T, A::T) where T
    nt, nf = 0, length(A)+1
    @inbounds for a in A
        if f(a)
            B[nt+=1] = a
        else
            B[nf-=1] = a
        end
    end
    fid = 1+nt
    reverse!(@view B[fid:end])
	return B, fid
end

"""
	separate(f::Function, A::AbstractVector{T})

Returns an `array` and `index` where `array[1:index-1]` holds all the values of `A` for which `f` returns `true`, and `array[index:end]` holds those for which `f` returns `false`.
"""
separate(f::Function, A::AbstractVector) =
	separate!(f, similar(A), A)

"""
	separateperm!(f::Function, ix::AbstractVector{Int}, A::AbstractVector)

Like `separateperm` but accepts a preallocated index vector `ix`.
"""
function separateperm!(f::Function, ix::AbstractVector{Int}, A::AbstractVector)
	la = length(A)
	@assert la <= length(ix) "Please supply an id vector that is of sufficient length (at least $la)."
	true_id = 1
	false_id = 0
	@inbounds for (i, a) in enumerate(A)
		if f(a)
			ix[true_id] = i
			true_id += 1
		else
			ix[end - false_id] = i
			false_id += 1
		end
	end
	reverse!(ix, true_id, la), true_id
end

"""
	separateperm(f::Function, A::AbstractVector)

Returns a `Vector{Int}` that can be used with `permute!` to separate `A` into values for which `f` returns `true` and those for which `f` returns `false`, and the first index where `f` returns false.
"""
function separateperm(f::Function, A::AbstractVector)
	ix = Vector{Int}(undef, length(A))
	return separateperm!(f, ix, A)
end


"""
	fillcopy(x, dims...)

Fills an array with deep copies of x.
"""
function fillcopy(x::T, dims...) where T
	out = Array{T, length(dims)}(undef, dims...)
	for i in eachindex(out)
		out[i] = deepcopy(x)
	end
	return out
end

"""
    findclosest(A::AbstractArray, v; by=(x,y) -> norm(x-y))

Returns the index to the closest value in `A` to `v`, using the two argument function of `by`.
"""
function findclosest(A::AbstractArray{T}, v; by::Function=(x,y) -> norm(x-y)) where {T}
    dist = typemax(typeof(by(A[1], v)))
    closestid = 0
    for (i, a) in enumerate(A)
        t = by(a, v)
        if t < dist
            closestid = i
            dist = t
        end
    end
    return closestid
end
    
"""
    getclosest(A::AbstractArray, v; by=(x,y) -> norm(x-y))

Returns the closest value in `A` to `v`, using the two argument function of `by`.
"""
function getclosest(A::AbstractArray{T}, v; by::Function=(x,y) -> norm(x-y)) where {T}
    dist = typemax(typeof(by(A[1], v)))
    closestval = A[1]
    for a in A
        t = by(a, v)
        if t < dist
            closestval = a
            dist = t
        end
    end
    return closestval
end
