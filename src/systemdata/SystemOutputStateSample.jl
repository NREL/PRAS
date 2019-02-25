struct RegionResult{L,T<:Period,P<:PowerUnit,V<:Real}

    net_injection::V
    surplus::V
    shortfall::V

    RegionResult{L,T,P}(
        net_injection::V, surplus::V, shortfall::V
    ) where {L,T<:Period,P<:PowerUnit,V<:Real} =
    new{L,T,P,V}(net_injection, surplus, shortfall)

end

struct InterfaceResult{L,T<:Period,P<:PowerUnit,V<:Real}

    max_transfer_magnitude::V
    transfer::V

    function InterfaceResult{L,T,P}(
        max::V, actual::V) where {L,T<:Period,P<:PowerUnit,V<:Real}
        new{L,T,P,V}(max, actual)
    end

end

struct SystemOutputStateSample{L,T,P,V}
    regions::Vector{RegionResult{L,T,P,V}}
    interfaces::Vector{InterfaceResult{L,T,P,V}}
    interfacelabels::Vector{Tuple{Int,Int}}

    function SystemOutputStateSample(
        regions::Vector{RegionResult{L,T,P,V}},
        interfaces::Vector{InterfaceResult{L,T,P,V}},
        interfacelabels::Vector{Tuple{Int,Int}}
    ) where {L,T,P,V}
        @assert length(interfaces) == length(interfacelabels)
        new{L,T,P,V}(regions, interfaces, interfacelabels)
    end
end

function SystemOutputStateSample{L,T,P,V}(
    interface_labels::Vector{Tuple{Int,Int}}, n::Int) where {L,T,P,V}

    regions = Vector{RegionResult{L,T,P,V}}(undef, n)
    interfaces = Vector{InterfaceResult{L,T,P,V}}(undef, length(interface_labels))
    return SystemOutputStateSample(regions, interfaces, interface_labels)

end

function droppedload(sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    isshortfall = false
    totalshortfall = zero(V)

    for region in sample.regions
        shortfall = region.shortfall
        if !(shortfall ≈ 0)
            isshortfall = true
            totalshortfall += shortfall
        end
    end

    return isshortfall, totalshortfall

end

function droppedloads!(localshortfalls::Vector{V},
                       sample::SystemOutputStateSample{L,T,P,V}) where {L,T,P,V}

    nregions = length(sample.regions)
    isshortfall = false
    totalshortfall = zero(V)

    for i in 1:nregions
        shortfall = sample.regions[i].shortfall
        if shortfall ≈ 0
            localshortfalls[i] = 0
        else
            isshortfall = true
            totalshortfall += shortfall
            localshortfalls[i] = shortfall
        end
    end

    return isshortfall, totalshortfall, localshortfalls

end

function all_load_served(A::Matrix{T}, B::Matrix{T}, sink::Int, n::Int) where T
    served = true
    i = 1
    while served && (i <= n)
        served = A[i, sink] ≈ B[i, sink]
        i += 1
    end
    return served
end
