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
    interfacelabels::Vector{Tuple{Int,Int}}

    function SystemOutputStateSample(
        regions::Vector{RegionResult{L,T,P}},
        interfaces::Vector{InterfaceResult{L,T,P}},
        interfacelabels::Vector{Tuple{Int,Int}}
    ) where {L,T,P}
        @assert length(interfaces) == length(interfacelabels)
        # TODO: Could also check that region indexes are valid
        new{L,T,P}(regions, interfaces, interfacelabels)
    end
end

function SystemOutputStateSample{L,T,P}(
    interface_labels::Vector{Tuple{Int,Int}}, n::Int) where {L,T,P}

    regions = Vector{RegionResult{L,T,P}}(undef, n)
    interfaces = Vector{InterfaceResult{L,T,P}}(undef, length(interface_labels))
    return SystemOutputStateSample(regions, interfaces, interface_labels)

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
