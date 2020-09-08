module Physics
	using Unitful
	import Unitful: FreeUnits, 𝐋
	using StaticArrays
	export σx, σy, σz
	export Ang, e₀, kₑ, a₀, Eₕ, Ry

	Unitful.register(@__MODULE__)
	Base.eltype(::Type{Length{T}}) where T = T
	@unit e₀  "eₒ"  ElementaryCharge      1.602176620898e-19*u"C" false
	@unit kₑ  "kₑ"  CoulombForceConstant  1/(4π)u"ϵ0"             false
	@unit a₀  "a₀"  BohrRadius            1u"ħ^2/(1kₑ*me*e₀^2)"   false
	@unit Eₕ  "Eₕ"  HartreeEnergy         1u"me*e₀^4*kₑ^2/(1ħ^2)" true
	@unit Ry  "Ry"  RydbergEnergy         0.5Eₕ                   true

	const localunits           = Unitful.basefactors
	const LengthType{T, A}     = Quantity{T,𝐋,FreeUnits{A,𝐋,nothing}}
	const ReciprocalType{T, A} = Quantity{T,𝐋^-1,FreeUnits{A,𝐋^-1,nothing}}

	Base.show(io::IO, ::Type{Quantity{T,𝐋,FreeUnits{A,𝐋,nothing}}}) where {T,A} =
	    dfprint(io, "LengthType{$T, $A}")

	@inline function StaticArrays._inv(::StaticArrays.Size{(3,3)}, A::SMatrix{3,3, LT}) where {LT<:Union{LengthType, ReciprocalType}}

	    @inbounds x0 = SVector{3}(A[1], A[2], A[3])
	    @inbounds x1 = SVector{3}(A[4], A[5], A[6])
	    @inbounds x2 = SVector{3}(A[7], A[8], A[9])

	    y0 = cross(x1,x2)
	    d  = StaticArrays.bilinear_vecdot(x0, y0)
	    x0 = x0 / d
	    y0 = y0 / d
	    y1 = cross(x2,x0)
	    y2 = cross(x0,x1)

	    @inbounds return SMatrix{3, 3}((y0[1], y1[1], y2[1], y0[2], y1[2], y2[2], y0[3], y1[3], y2[3]))
	end

	"Generates a Pauli σx matrix with the dimension that is passed through `n`."
	σx(::Type{T}, n::Int) where {T} =
		kron(Mat2([0 1; 1 0]), diagm(0 => ones(T, div(n, 2))))

	"Generates a Pauli σy matrix with the dimension that is passed through `n`."
	σy(::Type{T}, n::Int) where {T} =
		kron(Mat2([0 -1im; 1im 0]), diagm(0 => ones(T, div(n, 2))))

	"Generates a Pauli σz matrix with the dimension that is passed through `n`."
	σz(::Type{T}, n::Int) where {T} =
		kron(Mat2([1 0; 0 -1]), diagm(0 => ones(T, div(n, 2))))

	for s in (:σx, :σy, :σz)
		@eval @inline $s(m::AbstractArray{T}) where {T} =
			$s(T, size(m, 1))
	end

	function __init__()
		merge!(Unitful.basefactors, localunits)
		Unitful.register(@__MODULE__)
	end

end
