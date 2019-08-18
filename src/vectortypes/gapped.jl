"""
	mutable struct GappedVector{T} <: AbstractVector{T}

A `Vector` of vectors where the missing indices or 'gaps' don't take up memory.
Works for all intents and purposes as a normal `Vector`, but will throw a BoundsError when trying to directly access an index that lies inside a gap.
`getindex` doesn't have a lot of performance penalty, neither does iterating, but vecting indices is expensive.
I created this mainly for when I was experimenting with an entity component system and wanted to keep the same entity index inside all component vectors. 
"""
mutable struct GappedVector{T} <: AbstractVector{T}
	data::Vector{Vector{T}}
	ranges::Vector{UnitRange{Int}}
	function GappedVector{T}(vecs::Vector{Vector{T}}, start_ids::Vector{Int}) where T
		totlen = 0
		# Check that no overlaps would happen
		ranges = Vector{UnitRange{Int}}(undef, length(start_ids))
		for (i, (vec, sid)) in enumerate(zip(vecs, start_ids))
			if sid > totlen
				totlen += sid + length(vec) - 1
			else
				error("start id $sid would result in overlapping vectors, this is not allowed")
			end
			ranges[i] = sid:sid+length(vec) - 1 	
		end
		return new{T}(vecs, ranges)
	end
end


GappedVector{T}() where {T} = GappedVector{T}([T[]], Int[])
Base.isempty(A::GappedVector) = isempty(A.ranges)

Base.size(A::GappedVector)   = (length(A),)

function Base.length(A::GappedVector)
	l = 0
	for d in A.ranges
		l += length(d)
	end
	return l
end

Base.empty!(A::GappedVector{T}) where T =
	(A.ranges = UnitRange[]; A.data = [T[]])

extent(A::GappedVector) = last(A.ranges[end])

function Base.getindex(A::GappedVector, i::Int)
	for (r, bvec) in zip(A.ranges, A.data)
		if i ∈ r
			return bvec[i - first(r) + 1]
		end
	end
	error("Index $i is out of bounds.")
end

function overwrite!(A::GappedVector{T}, v::T, i::Int) where T
	for (r, bvec) in zip(A.ranges, A.data)
		if i ∈ r
			bvec[i - first(r) + 1] = v
		end
	end
end

increment_last(r::UnitRange) = first(r):last(r) + 1
decrement_last(r::UnitRange) = first(r):last(r) - 1
increment_first(r::UnitRange)= first(r)+1:last(r)
decrement_first(r::UnitRange)= first(r)-1:last(r)

function Base.push!(A::GappedVector{T}, v::T) where {T}
	if isempty(A)
		push!(A.data[1], v)
		push!(A.ranges, 1:1)
	else
		push!(A.data[end], v)
		A.ranges[end] = increment_last(A.ranges[end])
	end
	return v
end

data_vector_i(r, i) = i - first(r) + 1

function Base.setindex!(A::GappedVector{T}, v::T, i::Int) where T

	if isempty(A.ranges)
		push!(A.data[1], v)
		push!(A.ranges, i:i)
		return v
	elseif i == last(A.ranges[end]) + 1
		push!(A, v)
		return v
	elseif i > extent(A) + 1 
		push!(A.data, [v])
		push!(A.ranges, i:i)
		return v
	elseif i < first(A.ranges[1]) - 1  
		insert!(A.data, 1, [v])
		insert!(A.ranges, 1, i:i)
		return v
	else
		rl = length(A.ranges)
		for iv = 1:rl
			r = A.ranges[iv]
			bvec = A.data[iv]
			if i == last(r) + 1 # grow right
				push!(bvec, v)
				if iv < rl && last(r) + 2 == first(A.ranges[iv+1])
					append!(bvec, A.data[iv+1])
					A.ranges[iv] = first(r):last(A.ranges[iv+1])
					deleteat!(A.ranges, iv+1)
					deleteat!(A.data, iv+1)
				else
					A.ranges[iv] = increment_last(r)
				end
				return v
			elseif i == first(r) - 1 # grow lefti
				insert!(bvec, 1, v)
				A.ranges[iv] = decrement_first(r)
				return v

			elseif i ∈ r # overwrite
				bvec[data_vector_i(r, i)] = v
				return v
			elseif iv < rl && last(r) + 1 < i < first(A.ranges[iv+1]) - 1
				insert!(A.data, iv+1, [v])
				insert!(A.ranges, iv+1, i:i)
				return v
			end
		end
	end
end

Base.setindex!(g::GappedVector{T}, v, i::Int) where {T} =
	Base.setindex!(g, convert(T, v), i)

overlap(r1::T, r2::T) where {T<:Union{AbstractVector{Int}, UnitRange}} =
	r1[end] + 1 >= r2[1]

#does nothing when it doesn't have the index i
function Base.deleteat!(A::GappedVector, i::Int)
	val = A[i]
	for (vid, (r, bvec)) in enumerate(zip(A.ranges, A.data))
		startid = first(r)
		endid   = last(r)
		if startid < i < endid #insert new vector
			push!(A.ranges, i+1:endid)
			A.ranges[vid] = startid:i-1
			push!(A.data, bvec[i - startid + 2:end]) 
			A.data[vid] = bvec[1:i - startid]
		elseif i == endid #remove last element
			pop!(bvec)
			A.ranges[vid] = startid:endid - 1
		elseif i == startid #reseat one element over
			A.ranges[vid] = startid+1:endid
			A.data[vid]   = bvec[2:end]
		end
	end
	return val
end

Base.IndexStyle(::Type{<:GappedVector}) = IndexLinear()

function Base.iterate(A::GappedVector, state=(1,1))
	if state[1] > length(A.data)
		return nothing
	elseif state[2] == length(A.data[state[1]])
		return A.data[state[1]][state[2]], (state[1]+1, 1)
	else
		return A.data[state[1]][state[2]], (state[1], state[2]+1)
	end
end

function hasindex(A::GappedVector, i)
	for r in A.ranges
		if  i ∈ r
			return true
		end
	end
	return false
end


function Base.eachindex(A::GappedVector)
	t_r = Int[]
	for r in A.ranges
		append!(t_r, collect(r))
	end
	return t_r
end

function Base.pointer(A::GappedVector, i::Int)
	for (r, vec) in zip(A.ranges, A.data)
		if i ∈ r
			return pointer(vec, i - first(r) + 1)
		end
	end
	# This should never happen
	return pointer(A.data[end], i - first(A.ranges[end]) + 1)
end

#TODO Performance: this can be optimized quite a bit
ranges(A::GappedVector) = A.ranges
ranges(As::GappedVector...) = find_overlaps(ranges.(As))

function find_overlaps(ranges)
	out_ranges = UnitRange{Int}[]
	for r1 in ranges[1], r2 in ranges[2]
		tr = intersect(r1, r2)
		if !isempty(tr)
			push!(out_ranges, tr)
		end
	end
	return out_ranges
end

function find_overlaps(rangevecvec::Vector{Vector{UnitRange{Int}}})
	rs = rangevecvec[1]
	for rs2 in rangevecvec[2:end]
		rs = find_overlaps(rs, rs2)
	end
	return rs
end

function Base.show(io::IO, g::GappedVector{T}) where T
	println(io, "GappedVector{$T}")
	println(io, "\tlength: $(length(g))")
	println(io, "\tranges: $(g.ranges)")
end

function Base.Multimedia.display(io::IO, g::GappedVector{T}) where T
	println(io, "GappedVector{$T}")
	println(io, "\tlength: $(length(g))")
	println(io, "\tranges: $(g.ranges)")
end
function Base.Multimedia.display(g::GappedVector{T}) where T
	println("GappedVector{$T}")
	println("\tlength: $(length(g))")
	println("\tranges: $(g.ranges)")
end
