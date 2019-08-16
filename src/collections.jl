struct Regions{P<:PowerUnit}
    names::Vector{String}
    load::Matrix{Int}
end

struct Interfaces
    regions_from::Vector{Int}
    regions_to::Vector{Int}
end
