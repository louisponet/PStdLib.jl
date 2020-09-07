module PDataStructures
	using Reexport
	@reexport using DataStructures
	include("datastructures/TypedPage.jl")
	include("datastructures/GappedVector.jl")
	include("datastructures/LooseVector.jl")
<<<<<<< HEAD
	include("datastructures/PackedIntSet.jl")
	export PackedIntSet
	export TypedPage
=======
	export TypedPage
	export packed_id
>>>>>>> PackedIntSet
	export GappedVector
	export LooseVector

	const PAGESIZE = 0
	function __init__()
		global PAGESIZE = ccall(:jl_getpagesize, Clong, ())
	end
end
