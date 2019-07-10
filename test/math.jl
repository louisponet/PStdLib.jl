using PStdLib

@test isapprox(degree_to_radian(180), π)
@test isapprox(radian_to_degree(π), 180)
@test all(isapprox.(rθϕ_to_xyz(xyz_to_rθϕ(12.3, 1.2, -3.0)), (12.3, 1.2, -3.0)))
