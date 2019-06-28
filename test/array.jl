using PStdLib

a = 1:100
@test getfirst(x->x>50, a) == 51

b, c = separate(x -> x > 50, a)
@test length(b) == length(c) == 50

@test b[1] == 51
@test c[end] == 50

# tarr = collect(a)
# separate!(x -> x > 50, tarr)


t = [1.0]
tarr = fillcopy(t, 3)
@test all(pointer.(getindex.((tarr, ), 1:3)) .!= pointer(t))
