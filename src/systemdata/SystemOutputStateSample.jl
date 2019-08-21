struct RegionResult{L,T<:Period,P<:PowerUnit}
    net_injection::Int
    surplus::Int
    shortfall::Int
end

struct InterfaceResult{L,T<:Period,P<:PowerUnit}
    max_transfer_magnitude::Int
    transfer::Int
end

struct SystemOutputStateSample{L,T,P}
    regions::Vector{RegionResult{L,T,P}}
    interfaces::Vector{InterfaceResult{L,T,P}}
    regions_from::Vector{Int}
    regions_to::Vector{Int}

    function SystemOutputStateSample(
        regions::Vector{RegionResult{L,T,P}},
        interfaces::Vector{InterfaceResult{L,T,P}},
        regions_from::Vector{Int},
        regions_to::Vector{Int}
    ) where {L,T,P}
        n_regions = length(regions)
        n_interfaces = length(interfaces)
        @assert length(regions_from) == n_interfaces
        @assert length(regions_to) == n_interfaces
        # TODO: Could also check that region indexes are valid
        new{L,T,P}(regions, interfaces, regions_from, regions_to)
    end
end

function SystemOutputStateSample{L,T,P}(
    regions_from::Vector{Int}, regions_to::Vector{Int}, n::Int) where {L,T,P}

    regions = Vector{RegionResult{L,T,P}}(undef, n)
    interfaces = Vector{InterfaceResult{L,T,P}}(undef, length(regions_from))
    return SystemOutputStateSample(regions, interfaces, regions_from, regions_to)

end

function droppedload(sample::SystemOutputStateSample{L,T,P}) where {L,T,P}

    isshortfall = false
    totalshortfall = 0

    for region in sample.regions
        shortfall = region.shortfall
        if shortfall > 0
            isshortfall = true
            totalshortfall += shortfall
        end
    end

    return isshortfall, totalshortfall

end

function droppedloads!(localshortfalls::Vector{Int},
                       sample::SystemOutputStateSample{L,T,P}) where {L,T,P}

    nregions = length(sample.regions)
    isshortfall = false
    totalshortfall = 0

    for i in 1:nregions
        shortfall = sample.regions[i].shortfall
        if shortfall > 0
            isshortfall = true
            totalshortfall += shortfall
            localshortfalls[i] = shortfall
        else
            localshortfalls[i] = 0
        end
    end

    return isshortfall, totalshortfall, localshortfalls

end
