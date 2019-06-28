using PStdLib.BLASCaches
using LinearAlgebra

for F in (Float32, Float64)
	t = rand(Complex{F}, 50, 50)
	orig       = (t + t')/2
	normal_eig = eigen(orig)
	cache      = HermitianEigCache(orig)
	cached_eig = eigen(orig, cache)
	@test sum(normal_eig.values) ≈ sum(cached_eig.values) 
	@test Array(normal_eig) ≈ Array(cached_eig) ≈ orig
end
