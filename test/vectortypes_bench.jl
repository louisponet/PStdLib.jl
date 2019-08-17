using PStdLib.VectorTypes
using BenchmarkTools

res = @benchmark begin
	t = GappedVector{Int}([[1, 3, 4], [5, 6, 7]], [1, 20])
	t[19] = 6
	t[18] = 7
	t[24] = 13
	w = has_index(t, 24)
	v = length(t)
	t[23] = 10
	deleteat!(t, 23)

	p = pointer(t, 21)

end samples = 100
