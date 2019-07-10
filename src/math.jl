using LinearAlgebra: norm

@export degree_to_radian(deg) = deg // 180 * π
@export radian_to_degree(rad) = rad * 180 / π 

"""
	xyz_to_rθϕ(x, y, z)

Converts cartesian to spherical coordinates.
"""
@export function xyz_to_rθϕ(x, y, z)
	r = norm((x,y,z))
	θ = acos(z/r)
	ϕ = atan(y/r, x/r)
	return r, θ, ϕ
end
xyz_to_rθϕ(x::NTuple{3}) = xyz_to_rθϕ(x...)

"""
	rθϕ_to_xyz(r, θ, ϕ)

Converts spherical to cartesian coordinates.
"""
@export function rθϕ_to_xyz(r, θ, ϕ)
	x = r * sin(θ) * cos(ϕ)
	y = r * sin(θ) * sin(ϕ)
	z = r * cos(θ)
	return x, y, z
end
rθϕ_to_xyz(x::NTuple{3}) = rθϕ_to_xyz(x...)

