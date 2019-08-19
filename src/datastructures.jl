module VectorTypes
	include("datastructures/TypedPage.jl")
	include("datastructures/PackedIntSet.jl")
	include("datastructures/GappedVector.jl")
	include("datastructures/LooseVector.jl")
	export TypedPage
	export PackedIntSet
	export GappedVector
	export LooseVector
end
