module ResourceAdequacy

using Base.Dates
using StatsBase
using Distributions
using LightGraphs

export

    assess,

    # Units
    Year, Month, Week, Day, Hour, Minute,
    MW, GW,
    MWh, GWh, TWh,

    # Metrics
    LOLP, LOLE, EUE,
    val, stderr,

    # System distribution extraction methods
    Backcast, REPRA,

    # System assessment methods
    Copperplate, NetworkFlow,

    # CV Methods
    EFC

CapacityDistribution{T} = Distributions.Generic{T,Float64,Vector{T}}
CapacitySampler{T} = Distributions.GenericSampler{T, Vector{T}}

include("utils.jl")
include("metrics.jl")
include("systemdata.jl")
include("extraction.jl")
include("simulation.jl")
include("capacityvalue.jl")

end # module
