using PStdLib.PDataStructures
using PStdLib
t = GappedVector{Int}([[1, 3, 4], [5, 6, 7]], [1, 20])
@test t[1] == 1
@test t[3] == 4
@test t[20] == 5
t[19] = 6
t[18] = 7
t[24] = 13
@test in(24, t)
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


const set1 = LooseVector{Int}()
tids1 = unique(rand(1:900, 30))
for i in tids1
	set1[i] = 23
end
@test in(tids1[23], set1)
@test set1[tids1[23]] == 23

@test sum(set1) == 23*length(tids1)

const set2 = LooseVector{Int}()
tids2 = rand(1:900, 3000)
for i in tids2
	set2[i] = 55
end

n = (23+55) * length(intersect(tids1, tids2))
test_n = 0
# for id in zip(set1.indices, set2.indices)
# 	global test_n += set1[id[1]]+set2[id[2]]
# end
