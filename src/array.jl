"""
It's like filter()[1].
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
    return reverse(true_part), reverse(false_part)
end
 
"""
	separate!(f::Function, A::AbstractVector)

Line `separate` but in place, returning two views into `A` where first view has all the `true` second all the `false`.
This rearranges `A`.
"""
@export function separate(f::Function, A::AbstractVector)
	tf = x -> f(x) ? 0 : 1
	sort!(A, by=tf)
	false_id = findfirst(!f, A)
	return view(A, 1:false_id-1), view(A, false_id:length(A))
end


