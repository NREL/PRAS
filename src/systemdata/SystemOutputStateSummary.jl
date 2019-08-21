struct SystemOutputStateSummary{L,T<:Period,E<:EnergyUnit}
    lolp_system::Float64
    lolp_regions::Vector{Float64}
    eue_regions::Vector{Float64}

    SystemOutputStateSummary{L,T,E}(
        lolp_system::Float64, lolp_regions::Vector{Float64}, eue_regions::Vector{Float64}
        ) where {L, T<:Period, E<:EnergyUnit} =
        new{L,T,E}(lolp_system, lolp_regions, eue_regions)

end
