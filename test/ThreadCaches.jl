using PStdLib.ThreadCaches
using Base.Threads
using LinearAlgebra

ts = zeros(100)
for i = 1:nthreads()
	ts .+= 1:100
end

ts2 = ThreadCache(zeros(100))
@threads for i = 1:nthreads()
	ts2 .+= 1:100
end

@test all(gather(ts2) .== ts)

fillall!(ts2, 1.0)
@test all(ts2.caches[1] .== 1.0)

ts2 .*= 3.0
@test all(ts2.caches[1] .== 3.0)


fillall!(ts2, 1.0)
@threads for i = 1:nthreads()
	ts2 .*= 3.0
end
for i = 1:nthreads()
	@test all(ts2.caches[i] .== 3.0)
end

ts3 = ThreadCache(ones(100))
@threads for i=1:nthreads()
	mul!(ts3, ts2, 3.0)
	mul!(ts3, 3.0, ts3)
end

for i = 1:nthreads()
	@test all(ts3.caches[i] .== 27.0)
end

test_caches = [zeros(100) for i=1:nthreads()]
@threads for i = 1:nthreads()
	mul!(test_caches[i], ts3, 1/3)
	mul!(test_caches[i], 1/3, ts3)
end

for i = 1:nthreads()
	@test all(test_caches[i] .== 9.0)
end

ts2 = ThreadCache(ones(100, 100))
ts3 = ThreadCache(ones(100, 100))

@threads for i = 1:nthreads()
	ts2 .*= 3.0
	mul!(ts3, ts2, ts2)
end

for i = 1:nthreads()
	@test all(ts3.caches[i] .== 900)
end

ts2 = ThreadCache(ones(100, 100))
@test ts2 * 5 == 5*ts2 == 5*ones(100, 100)

t = 1im * ones(100, 100)
ts2 = ThreadCache(zeros(ComplexF64, 100, 100))

adjoint!(ts2, t)
@test PStdLib.ThreadCaches.cache(ts2) == adjoint(t)

ts2 = ThreadCache(t)
ts3 = ThreadCache(t)
adjoint!(ts2, adjoint!(ts3, ts2))

@test PStdLib.ThreadCaches.cache(ts2) == t

@test adjoint(ts2) == adjoint(t)

@test ndims(typeof(ts2)) == ndims(typeof(t))













