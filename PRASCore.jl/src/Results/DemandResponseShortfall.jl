"""
    DemandResponseShortfall

The `DemandResponseShortfall` result specification reports expectation-based resource
adequacy risk metrics such as EUE and LOLE associated with DemandResponse devices only, producing a `DemandResponseShortfallResult`.

A `DemandResponseShortfallResult` can be directly indexed by a region name and a timestamp to retrieve a tuple of sample mean and standard deviation, estimating
 the average unserved energy in that region and timestep. However, in most
cases it's simpler to use [`EUE`](@ref) and [`LOLE`](@ref) constructors to
directly retrieve standard risk metrics.

Example:

```julia
DemandResponseShortfall, =
    assess(sys, SequentialMonteCarlo(samples=1000), DemandResponseShortfall())

period = ZonedDateTime(2020, 1, 1, 0, tz"UTC")

# Unserved energy mean and standard deviation
sf_mean, sf_std = DemandResponseShortfall["Region A", period]

# System-wide risk metrics
eue = EUE(DemandResponseShortfall)
lole = LOLE(DemandResponseShortfall)
neue = NEUE(DemandResponseShortfall)

# Regional risk metrics
regional_eue = EUE(DemandResponseShortfall, "Region A")
regional_lole = LOLE(DemandResponseShortfall, "Region A")
regional_neue = NEUE(DemandResponseShortfall, "Region A")

# Period-specific risk metrics
period_eue = EUE(DemandResponseShortfall, period)
period_lolp = LOLE(DemandResponseShortfall, period)

# Region- and period-specific risk metrics
period_eue = EUE(DemandResponseShortfall, "Region A", period)
period_lolp = LOLE(DemandResponseShortfall, "Region A", period)
```

See [`DemandResponseShortfallSamples`](@ref) for recording sample-level DemandResponseShortfall results.
"""
struct DemandResponseShortfall <: ResultSpec end

mutable struct DemandResponseShortfallAccumulator  <: ResultAccumulator{DemandResponseShortfall}
    base::ShortfallAccumulator
end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseShortfall
) where {N}
    base_acc = accumulator(sys, nsamples, Shortfall())  # call original accumulator
    return DemandResponseShortfallAccumulator(base_acc)
end



function merge!(x::DemandResponseShortfallAccumulator, y::DemandResponseShortfallAccumulator)
    merge!(x.base, y.base)
end

accumulatortype(::DemandResponseShortfall) = DemandResponseShortfallAccumulator


struct DemandResponseShortfallResult{N,L,T,E}  <: AbstractShortfallResult{N, L, T}
    base::ShortfallResult{N,L,T,E}
end

function DemandResponseShortfallResult{N,L,T,E}(
    nsamples::Union{Int,Nothing},
    regions::Regions,
    timestamps::StepRange{ZonedDateTime,T},
    eventperiod_mean::Float64,
    eventperiod_std::Float64,
    eventperiod_region_mean::Vector{Float64},
    eventperiod_region_std::Vector{Float64},
    eventperiod_period_mean::Vector{Float64},
    eventperiod_period_std::Vector{Float64},
    eventperiod_regionperiod_mean::Matrix{Float64},
    eventperiod_regionperiod_std::Matrix{Float64},
    shortfall_mean::Matrix{Float64},
    shortfall_std::Float64,
    shortfall_region_std::Vector{Float64},
    shortfall_period_std::Vector{Float64},
    shortfall_regionperiod_std::Matrix{Float64}
) where {N,L,T<:Period,E<:EnergyUnit}
    DemandResponseShortfallResult(
        ShortfallResult{N,L,T,E}(
            nsamples, regions, timestamps,
            eventperiod_mean, eventperiod_std,
            eventperiod_region_mean, eventperiod_region_std,
            eventperiod_period_mean, eventperiod_period_std,
            eventperiod_regionperiod_mean, eventperiod_regionperiod_std,
            shortfall_mean, shortfall_std,
            shortfall_region_std, shortfall_period_std,
            shortfall_regionperiod_std)
    )

end


function getindex(x::DemandResponseShortfallResult)
    return getindex(x.base)
end

function getindex(x::DemandResponseShortfallResult, r::AbstractString)
    return getindex(x.base, r)
end

function getindex(x::DemandResponseShortfallResult, t::ZonedDateTime)
    return getindex(x.base, t)
end

function getindex(x::DemandResponseShortfallResult, r::AbstractString, t::ZonedDateTime)
    return getindex(x.base, r, t)
end


LOLE(x::DemandResponseShortfallResult{N,L,T}) where {N,L,T} =
    LOLE(x.base)

function LOLE(x::DemandResponseShortfallResult{N,L,T}, r::AbstractString) where {N,L,T}
    return LOLE(x.base, r)
end

function LOLE(x::DemandResponseShortfallResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    return LOLE(x.base, t)
end

function LOLE(x::DemandResponseShortfallResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    return LOLE(x.base, r, t)
end

EUE(x::DemandResponseShortfallResult{N,L,T,E}) where {N,L,T,E} =
    EUE(x.base)

EUE(x::DemandResponseShortfallResult{N,L,T,E}, r::AbstractString) where {N,L,T,E} =
    EUE(x.base, r)

EUE(x::DemandResponseShortfallResult{N,L,T,E}, t::ZonedDateTime) where {N,L,T,E} =
    EUE(x.base, t)

EUE(x::DemandResponseShortfallResult{N,L,T,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,E} =
    EUE(x.base, r, t)

function NEUE(x::DemandResponseShortfallResult{N,L,T,E}) where {N,L,T,E}
    return NEUE(x.base)
end

function NEUE(x::DemandResponseShortfallResult{N,L,T,E}, r::AbstractString) where {N,L,T,E}
    return NEUE(x.base, r)
end


function finalize(
    acc::DemandResponseShortfallAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    base_result = finalize(acc.base, system)

    return DemandResponseShortfallResult(base_result)
end
