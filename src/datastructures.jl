module PDataStructures
	using Reexport
	@reexport using DataStructures
	include("datastructures/TypedPage.jl")
	include("datastructures/GappedVector.jl")
	include("datastructures/LooseVector.jl")
	export TypedPage
	export packed_id
	export GappedVector
	export LooseVector

	const PAGESIZE = ccall(:jl_getpagesize, Clong, ())
end
