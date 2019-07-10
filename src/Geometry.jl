module Geometry
	using StaticArrays
	using InlineExports
	const Point{N, F} = SVector{N, F}
	const Point2{F} = SVector{2, F} 
	const Vec2{F}   = SVector{2, F}
	const Point3{F} = SVector{3, F} 
	const Vec3{F}   = SVector{3, F}

	const Mat2{F}   = SMatrix{2, 2, F, 4}
	const Mat3{F}   = SMatrix{3, 3, F, 9}
	const Mat4{F}   = SMatrix{4, 4, F, 16}
	export Point, Point3, Vec3, Mat3, Mat4

	@export volume(m::Mat3) = det(m)

	"""
		reciprocal(cell::Mat3)

	Calculates the reciprocal cell of a columnwise ordered unit cell.
	`2π*inv(cell)'`.
	"""
	@export reciprocal(cell::Mat3) =
		2π*inv(cell)'

	xyz_to_rθϕ(v::Vec3) = Vec3(xyz_to_rθϕ(v...))

	rθϕ_to_xyz(v::Vec3) = Vec3(rθϕ_to_xyz(v...))
	
end
