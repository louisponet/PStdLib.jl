module BLASCaches
	import LinearAlgebra.LAPACK: syev!, @blasfunc, BlasInt, chkstride1, checksquare, chklapackerror, liblapack
	import LinearAlgebra.BLAS: libblas
	import LinearAlgebra: eigen, eigen!, Eigen
	import Base: @propagate_inbounds
	using InlineExports


	# We use Upper Triangular blas for everything! And Eigvals are always all calculated
	@inline function blas_eig_ccall(A     ::AbstractMatrix{ComplexF32},
		                    W     ::AbstractVector{Float32},
	                        work  ::Vector{ComplexF32},
	                        lwork ::BlasInt,
	                        rwork ::Vector{Float32},
	                        n     ::Int,
	                        info  ::Ref{BlasInt})

		ccall((@blasfunc(cheev_), liblapack), Cvoid,
		          (Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{ComplexF32}, Ref{BlasInt},
		          Ptr{Float32}, Ptr{ComplexF32}, Ref{BlasInt}, Ptr{Float32}, Ptr{BlasInt}),
		          'V', 'U', n, A, n, W, work, lwork, rwork, info)
		chklapackerror(info[])
	end
	@inline function blas_eig_ccall(A     ::AbstractMatrix{ComplexF64},
		                    W     ::AbstractVector{Float64},
	                        work  ::Vector{ComplexF64},
	                        lwork ::BlasInt,
	                        rwork ::Vector{Float64},
	                        n     ::Int,
	                        info  ::Ref{BlasInt})

		ccall((@blasfunc(zheev_), liblapack), Cvoid,
		          (Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{ComplexF64}, Ref{BlasInt},
		          Ptr{Float64}, Ptr{ComplexF64}, Ref{BlasInt}, Ptr{Float64}, Ptr{BlasInt}),
		          'V', 'U', n, A, n, W, work, lwork, rwork, info)
		chklapackerror(info[])
	end

	"""
		HermitianEigCache{T <: AbstractFloat}

	A cache that can be used with multiple eigenvalue decompositions with the same workbuffers.
	This should be used only with Complex Hermitian Matrices.
	"""
	@export struct HermitianEigCache{T <: AbstractFloat}
		work   ::Vector{Complex{T}}
		lwork  ::BlasInt
		rwork  ::Vector{T}
		n      ::Int
		info   ::Ref{BlasInt}
		function HermitianEigCache(A::AbstractMatrix{Complex{relty}}) where {relty}
			chkstride1(A)
			elty = Complex{relty}
		    n = checksquare(A)
		    W     = similar(A, relty, n)
		    work  = Vector{elty}(undef, 1)
		    lwork = BlasInt(-1)
		    rwork = Vector{relty}(undef, max(1, 3n-2))
		    info  = Ref{BlasInt}()

			blas_eig_ccall(A, W, work, lwork, rwork, n, info)
		    lwork = BlasInt(real(work[1]))
		    resize!(work, lwork)
		    return new{relty}(work, lwork, rwork, n, info)
	    end
	end

	@inline function eigen!(vals::AbstractVector{T}, vecs::AbstractMatrix{Complex{T}}, c::HermitianEigCache{T}) where {T}
		blas_eig_ccall(vecs, vals, c.work, c.lwork, c.rwork, c.n, c.info)
		return Eigen(vals, vecs)
	end

	@inline function eigen(vecs::AbstractMatrix{Complex{T}}, c::HermitianEigCache{T}) where {T}
		out  = copy(vecs)
		vals = similar(out, T, size(out, 2))
		return eigen!(vals, out, c)
	end

end
