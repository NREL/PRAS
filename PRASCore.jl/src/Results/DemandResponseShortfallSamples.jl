"""
    DemandResponseShortfallSamples

The `DemandResponseShortfallSamples` result specification reports sample-level unserved energy outcomes, producing a `DemandResponseShortfallSamplesResult`.

A `DemandResponseShortfallSamplesResult` can be directly indexed by a region name and a
timestamp to retrieve a vector of sample-level unserved energy results in that
region and timestep. [`EUE`](@ref) and [`LOLE`](@ref) constructors can also
be used to retrieve standard risk metrics.

Example:

```julia
drshortfall, =
    assess(sys, SequentialMonteCarlo(samples=10), DemandResponseShortfallSamples())

period = ZonedDateTime(2020, 1, 1, 0, tz"UTC")

samples = drshortfall["Region A", period]

@assert samples isa Vector{Float64}
@assert length(samples) == 10

# System-wide risk metrics
eue = EUE(drshortfall)
lole = LOLE(drshortfall)
neue = NEUE(drshortfall)

# Regional risk metrics
regional_eue = EUE(drshortfall, "Region A")
regional_lole = LOLE(drshortfall, "Region A")
regional_neue = NEUE(drshortfall, "Region A")

# Period-specific risk metrics
period_eue = EUE(drshortfall, period)
period_lolp = LOLE(shortfall, period)

# Region- and period-specific risk metrics
period_eue = EUE(drshortfall, "Region A", period)
period_lolp = LOLE(drshortfall, "Region A", period)
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`DemandResponseShortfall`](@ref) for average shortfall outcomes when sample-level granularity isn't required.
"""
struct DemandResponseShortfallSamples <: ResultSpec end

struct DemandResponseShortfallSamplesAccumulator <: ResultAccumulator{DemandResponseShortfallSamples}

    shortfall::Array{Int,3}

end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseShortfallSamples
) where {N}

    nregions = length(sys.regions)
    shortfall = zeros(Int, nregions, N, nsamples)

    return DemandResponseShortfallSamplesAccumulator(shortfall)

end

function merge!(
    x::DemandResponseShortfallSamplesAccumulator, y::DemandResponseShortfallSamplesAccumulator
)

    x.shortfall .+= y.shortfall
    return

end

accumulatortype(::DemandResponseShortfallSamples) = DemandResponseShortfallSamplesAccumulator

struct DemandResponseShortfallSamplesResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractShortfallResult{N,L,T}

    regions::Regions{N,P}
    timestamps::StepRange{ZonedDateTime,T}

    shortfall::Array{Int,3} # r x t x s

end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}
) where {N,L,T,P,E}
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(x.shortfall, dims=1:2))
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, i_r, :, :), dims=1))
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime
) where {N,L,T,P,E}
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * sum(view(x.shortfall, :, i_t, :), dims=1))
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime
) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    p2e = conversionfactor(L, T, P, E)
    return vec(p2e * x.shortfall[i_r, i_t, :])
end


function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}) where {N,L,T}
    eventperiods = sum(sum(x.shortfall, dims=1) .> 0, dims=2)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, r::AbstractString) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    eventperiods = sum(view(x.shortfall, i_r, :, :) .> 0, dims=1)
    return LOLE{N,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = sum(view(x.shortfall, :, i_t, :), dims=1) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    i_r = findfirstunique(x.regions.names, r)
    i_t = findfirstunique(x.timestamps, t)
    eventperiods = view(x.shortfall, i_r, i_t, :) .> 0
    return LOLE{1,L,T}(MeanEstimate(eventperiods))
end


EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[]))

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E} =
    EUE{N,L,T,E}(MeanEstimate(x[r]))

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[t]))

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE{1,L,T,E}(MeanEstimate(x[r, t]))

function NEUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E}
    return NEUE(div(MeanEstimate(x[]),(sum(x.regions.load)/1e6)))
end

function NEUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    i_r = findfirstunique(x.regions.names, r)
    return NEUE(div(MeanEstimate(x[r]),(sum(x.regions.load[i_r,:])/1e6)))
end

function finalize(
    acc::DemandResponseShortfallSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}

    return DemandResponseShortfallSamplesResult{N,L,T,P,E}(
        system.regions, system.timestamps, acc.shortfall)

end
