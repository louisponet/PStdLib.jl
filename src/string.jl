"""
Searches a directory for all files containing the key.
"""
@export searchdir(path::String, key) = filter(x -> occursin(key, x), readdir(path))

"""
Splits a line using arguments, then strips spaces from the splits.
"""
@export strip_split(line, args...) = strip.(split(line, args...))

"""
	replace_multiple(str::AbstractString, replacements::Pair{AbstractString, AbstractString}...)

Replaces multiple substrings in `str`, one after the other.
"""
@export function replace_multiple(str, replacements::Pair{String, String}...)
    tstr = deepcopy(str)
    for r in replacements
        tstr = replace(tstr, r)
    end
    return tstr
end

"""
	cut_after(line::AbstractString, c::Char)

Cuts the line at `c` and returns up to it (not including).
"""
@export function cut_after(line::AbstractString, c::Char)
    t = findfirst(isequal(c), line)
    if t == nothing
        return line
    elseif t == 1
        return ""
    else
        return line[1:t - 1]
    end
end


