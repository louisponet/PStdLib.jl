"""
Like `filter()[1]`.
"""
@export function getfirst(f::Function, A)
    for el in A
        if f(el)
            return el
        end
    end
end

"""
	separate!(f::Function, A::AbstractVector, ix::AbstractVector{Int}=Vector{Int}(undef, length(A)))

Like `separate` but in place, `ix` is a id buffer that will be used in `separateperm!`, of at least length of `A`. 
"""
@export function separate!(f::Function, A::AbstractVector, ix::AbstractVector{Int}=Vector{Int}(undef, length(A)))
	ix, id = separateperm!(f, ix, A)
	permute!(A, ix)
	return A, id
end

"""
	separate(f::Function, A::AbstractVector{T})

Returns an `array` and `index` where `arra[1:index-1]` holds all the values of `A` for which `f` returns `true`, and `array[index:end]` holds those for which `f` returns `false`.
"""
@export separate(f::Function, A::AbstractVector) =
	separate!(f, deepcopy(A))

"""
	separateperm!(f::Function, ix::AbstractVector{Int}, A::AbstractVector)

Like `separateperm` but accepts a preallocated index vector `ix`.
"""
@export function separateperm!(f::Function, ix::AbstractVector{Int}, A::AbstractVector)
	la = length(A)
	@assert la <= length(ix) "Please supply an id vector that is of sufficient length (at least $la)."
	true_id = 1
	false_id = 0
	for (i, a) in enumerate(A)
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
@export function separateperm(f::Function, A::AbstractVector)
	ix = Vector{Int}(undef, length(A))
	return separateperm!(f, ix, A)
end


"""
	fillcopy(x, dims...)

Fills an array with deep copies of x.
"""
@export function fillcopy(x::T, dims...) where T
	out = Array{T, length(dims)}(undef, dims...)
	for i in eachindex(out)
		out[i] = deepcopy(x)
	end
	return out
end

