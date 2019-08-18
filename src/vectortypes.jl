module VectorTypes
	include("vectortypes/gapped.jl")
	include("vectortypes/loose.jl")
	export GappedVector, LooseVector
	export hasindex
end
