module DataStructures
	include("datastructures/TypedPage.jl")
	include("datastructures/PackedIntSet.jl")
	include("datastructures/GappedVector.jl")
	include("datastructures/LooseVector.jl")
	export TypedPage
	export PackedIntSet
	export packed_id
	export GappedVector
	export LooseVector
	export pointer_zip
	export cleanup!

	const PAGESIZE = 0
	function __init__()
		global PAGESIZE = ccall(:jl_getpagesize, Clong, ())
	end
end
