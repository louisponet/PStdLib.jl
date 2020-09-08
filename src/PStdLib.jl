module PStdLib
	using InlineExports
	using Reexport
	@reexport using Parameters

	include("Geometry.jl")
	include("Physics.jl")
	include("array.jl")
	export fillcopy,
	       norm2,
	       getfirst,
	       separate!,
	       separate,
	       separateperm!,
	       separateperm,
	       fillcopy,
	       findclosest,
	       getclosest
	       
	include("string.jl")
	include("math.jl")
	include("ThreadCaches.jl")
	include("BLASCaches.jl")
	include("datastructures.jl")
	include("images.jl")
	#general Utility functions
	"Like `joinpath(homedir(), args...)`"
	@export homepath(args...) =
		joinpath(homedir(), args...)

end
