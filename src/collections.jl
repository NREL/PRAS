struct Regions{N,P<:PowerUnit}

    names::Vector{String}
    load::Matrix{Int}

    function Regions{N,P}(
        names::Vector{String}, load::Matrix{Int}
    ) where {N,P<:PowerUnit}

        n_regions = length(names)

        @assert size(load) == (n_regions, N)

        new{N,P}(names, load)

    end

end

length(r::Regions) = length(r.names)

struct Interfaces{N,P<:PowerUnit}

    regions_from::Vector{Int}
    regions_to::Vector{Int}
    limit_forward::Matrix{Int}
    limit_backward::Matrix{Int}

    function Interfaces{N,P}(
        regions_from::Vector{Int}, regions_to::Vector{Int},
        forwardcapacity::Matrix{Int}, backwardcapacity::Matrix{Int}
    ) where {N,P<:PowerUnit}

        n_interfaces = length(regions_from)
        @assert length(regions_to) == n_interfaces

        @assert size(forwardcapacity) == (n_interfaces, N)
        @assert size(backwardcapacity) == (n_interfaces, N)

        new{N,P}(regions_from, regions_to, forwardcapacity, backwardcapacity)

    end

end

length(i::Interfaces) = length(i.regions_from)
