struct SystemOutputStateSummary{L, T<:Period, E<:EnergyUnit, V<:Real}
    lolp_system::V
    lolp_regions::Vector{V}
    eue_regions::Vector{V}

    SystemOutputStateSummary{L,T,E}(
        lolp_system::V, lolp_regions::Vector{V}, eue_regions::Vector{V}
        ) where {L, T<:Period, E<:EnergyUnit, V<:Real} =
        new{L,T,E,V}(lolp_system, lolp_regions, eue_regions)

end
