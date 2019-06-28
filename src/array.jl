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
	separate(f::Function, A::AbstractVector{T})

Separates array `A` into two arrays, one where `f` is `true`, the other where `f` is false.
"""
@export function separate(f::Function, A::AbstractVector{T}) where T
    true_part = T[]
    false_part = T[]
    for t in A
        if f(t)
            push!(true_part, t)
        else
            push!(false_part, t)
        end
    end
    return true_part, false_part
end
 
"""
	separate!(f::Function, A::AbstractVector)

Like `separate` but in place, returning two views into `A` where first view has all the `true` second all the `false`.
This rearranges `A`.
"""
@export function separate!(f::Function, A::AbstractVector)
	true_counter = 1
	false_counter = -1
	tf = x -> f(x) ? (true_counter += 1; true_counter) : (false_counter -= 1; false_counter)
	sort!(A, by=tf)
	false_id = findfirst(!f, A)
	return view(A, 1:false_id-1), view(A, false_id:length(A))
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

