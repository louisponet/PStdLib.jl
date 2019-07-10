module PStdLib
	using InlineExports
	include("Geometry.jl")
	include("Physics.jl")
	include("array.jl")
	include("string.jl")
	include("math.jl")
	include("ThreadCaches.jl")
	include("BLASCaches.jl")
	#general Utility functions
	"Like `joinpath(homedir(), args...)`"
	@export homepath(args...) =
		joinpath(homedir(), args...)

end
