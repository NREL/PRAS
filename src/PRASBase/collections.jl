struct Regions{N,P<:PowerUnit}

    names::Vector{String}
    load::Matrix{Int}

    function Regions{N,P}(
        names::Vector{<:AbstractString}, load::Matrix{Int}
    ) where {N,P<:PowerUnit}

        n_regions = length(names)

        @assert size(load) == (n_regions, N)
        @assert all(load .>= 0)

        new{N,P}(string.(names), load)

    end

end

Base.:(==)(x::T, y::T) where {T <: Regions} =
    x.names == y.names &&
    x.load == y.load

Base.length(r::Regions) = length(r.names)

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
        @assert all(forwardcapacity .>= 0)
        @assert all(backwardcapacity .>= 0)

        new{N,P}(regions_from, regions_to, forwardcapacity, backwardcapacity)

    end

end

Base.:(==)(x::T, y::T) where {T <: Interfaces} =
    x.regions_from == y.regions_from &&
    x.regions_to == y.regions_to &&
    x.limit_forward == y.limit_forward &&
    x.limit_backward == y.limit_backward

Base.length(i::Interfaces) = length(i.regions_from)
