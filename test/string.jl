using PStdLib

@test "runtests.jl" ∈ searchdir(".", ".jl")

@test strip_split(" d e d       ")[3] == "d"
@test replace_multiple("ded", "d"=>"f", "e" => "i", "f" => "g") == "gig"
@test cut_after("ded", 'e') == "d"
@test cut_after("ded", 'd') == ""
@test cut_after("ded", 'f') == "ded"
