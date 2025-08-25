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
period_lolp = LOLE(drshortfall, period)

# Region- and period-specific risk metrics
period_eue = EUE(drshortfall, "Region A", period)
period_lolp = LOLE(drshortfall, "Region A", period)
```

Note that this result specification requires large amounts of memory for
larger sample sizes. See [`DemandResponseShortfall`](@ref) for average shortfall outcomes when sample-level granularity isn't required.
"""
struct DemandResponseShortfallSamples <: ResultSpec end

struct DemandResponseShortfallSamplesAccumulator <: ResultAccumulator{DemandResponseShortfallSamples}
    base::ShortfallSamplesAccumulator
end

function accumulator(
    sys::SystemModel{N}, nsamples::Int, ::DemandResponseShortfallSamples
) where {N}
    base_acc = accumulator(sys, nsamples, ShortfallSamples())  # call original accumulator
    return DemandResponseShortfallSamplesAccumulator(base_acc)
end

function merge!(
    x::DemandResponseShortfallSamplesAccumulator, y::DemandResponseShortfallSamplesAccumulator
)
    merge!(x.base, y.base)
end

accumulatortype(::DemandResponseShortfallSamples) = DemandResponseShortfallSamplesAccumulator

struct DemandResponseShortfallSamplesResult{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} <: AbstractShortfallResult{N,L,T}
    base::ShortfallSamplesResult{N,L,T,P,E}
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}
) where {N,L,T,P,E}
    return getindex(x.base)
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString
) where {N,L,T,P,E}
    return getindex(x.base, r)
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime
) where {N,L,T,P,E}
    return getindex(x.base, t)
end

function getindex(
    x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime
) where {N,L,T,P,E}
    return getindex(x.base, r, t)
end


function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}) where {N,L,T}
    return LOLE(x.base)
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, r::AbstractString) where {N,L,T}
    return LOLE(x.base, r)
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, t::ZonedDateTime) where {N,L,T}
    return LOLE(x.base, t)
end

function LOLE(x::DemandResponseShortfallSamplesResult{N,L,T}, r::AbstractString, t::ZonedDateTime) where {N,L,T}
    return LOLE(x.base, r, t)
end


EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E} =
    EUE(x.base)

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E} =
    EUE(x.base, r)

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE(x.base, t)

EUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString, t::ZonedDateTime) where {N,L,T,P,E} =
    EUE(x.base, r, t)

function NEUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}) where {N,L,T,P,E}
    return NEUE(x.base)
end

function NEUE(x::DemandResponseShortfallSamplesResult{N,L,T,P,E}, r::AbstractString) where {N,L,T,P,E}
    return NEUE(x.base, r)
end

function finalize(
    acc::DemandResponseShortfallSamplesAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    base_result = finalize(acc.base, system)

    return DemandResponseShortfallSamplesResult(base_result)

end
