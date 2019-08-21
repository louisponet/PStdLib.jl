using BenchmarkTools
using PStdLib.DataStructures

SUITE = BenchmarkGroup()

SUITE["PackedIntSet"] = BenchmarkGroup()

SUITE["PackedIntSet"]["push"] = @benchmarkable push!(y, x) setup=(y=PackedIntSet(1:300); x=rand(5999:1000000))
