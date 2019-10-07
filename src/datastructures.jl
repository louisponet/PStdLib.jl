module PDataStructures
	using Reexport
	@reexport using DataStructures
	include("datastructures/TypedPage.jl")
	include("datastructures/GappedVector.jl")
	include("datastructures/LooseVector.jl")
	include("datastructures/PackedIntSet.jl")
	export PackedIntSet
	export TypedPage
	export GappedVector
	export LooseVector
	export pointer_zip
	export cleanup!

	const PAGESIZE = 0
	function __init__()
		global PAGESIZE = ccall(:jl_getpagesize, Clong, ())
	end
end
