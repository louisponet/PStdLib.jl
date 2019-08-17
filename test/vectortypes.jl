using PStdLib.VectorTypes
t = GappedVector{Int}([[1, 3, 4], [5, 6, 7]], [1, 20])
@test t[1] == 1
@test t[3] == 4
@test t[20] == 5
t[19] = 6
t[18] = 7
t[24] = 13
@test has_index(t, 24)
@test length(t.data) == 3
t[23] = 10 
@test length(t.data) == 2
@test t[19] == 6
@test t[18] == 7
@test t[24] == 13
@test t[23] == 10


deleteat!(t, 23)
@test length(t.data) == 3

v = GappedVector{Int}([[1,2,3],[4,5,6]], [1, 20])
@test pointer(v, 21) == pointer(v.data[end],2)

@test length(eachindex(v)) == 6

vt = Int[]
for v_ in v
	push!(vt, v_)
end
@test vt == 1:6

