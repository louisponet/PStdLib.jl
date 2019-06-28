module PStdLib
	using InlineExports
	include("Geometry.jl")
	include("array.jl")
	include("string.jl")
	include("math.jl")
	include("ThreadCache.jl")
	include("HermitianEigCache.jl")
	#general Utility functions
	"Like `joinpath(homedir(), args...)`"
	@export homepath(args...) =
		joinpath(homedir(), args...)

end
