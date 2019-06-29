using PStdLib

a = 1:100
@test getfirst(x->x>50, a) == 51

for i = 1:10
	a = 100 .* rand(100)
	b, id = separate(x -> x > 50, a)
	@test all(map(x->x > 50, b[1:id-1]))
	@test all(map(x->x <= 50, b[id:end]))
	ids, id = separateperm(x -> x > 50, a)

	@test all(map(x->x > 50, a[ids[1:id-1]]))
	@test all(map(x->x <= 50, a[ids[id:end]]))
end

t = [1.0]
tarr = fillcopy(t, 3)
@test all(pointer.(getindex.((tarr, ), 1:3)) .!= pointer(t))
