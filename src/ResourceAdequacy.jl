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

    # RA Methods
    REPRA, REPRA_T,

    # CV Methods
    EFC

include("units.jl")
include("SystemDistribution.jl")
include("SystemDistributionSet.jl")
include("conv.jl")

include("metrics.jl")
include("reliability.jl")
include("capacityvalue.jl")

end # module
