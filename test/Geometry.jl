using PStdLib.Geometry
using LinearAlgebra

@test isapprox(dot(normalize(Vec3(1,1,1)), normalize(Vec3(1,1,1))), 1.0)
@test isapprox(dot(normalize(Point3(1,1,1)), normalize(Point3(1,1,1))), 1.0)
