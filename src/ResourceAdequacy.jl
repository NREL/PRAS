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
    LOLP, LOLE, EUE, # Types
    lolp, lole, eue, # Getter methods
    val, stderr,

    # RA Methods
    REPRA, REPRA_T


# Types and type methods
include("units.jl")
include("metrics.jl")
include("SystemDistribution.jl")
include("SystemDistributionSet.jl")

# Helper functions
include("conv.jl")

# Adequacy assessment techniques and result types
include("reliabilityassessment.jl")
include("valuationmethods.jl")

end # module
