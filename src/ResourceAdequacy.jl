module ResourceAdequacy

using MinCostFlows
using PRASBase

import Base: -, broadcastable
import Base.Threads: nthreads, @spawn
import Dates: DateTime, Period, Year, Month, Week, Day, Hour, Minute
import Decimals: Decimal
import Distributions: DiscreteNonParametric, probs, support
import Future: randjump
import MinCostFlows: solveflows!
import OnlineStats: EqualWeight, Mean, Series, Sum, Variance, fit!, value
import Random: MersenneTwister, rand
import StatsBase: stderror

export

    assess,

    # Units
    Year, Month, Week, Day, Hour, Minute,
    MW, GW,
    MWh, GWh, TWh,

    # Metrics
    LOLP, LOLE, EUE, ExpectedInterfaceFlow, ExpectedInterfaceUtilization,
    val, stderror,

    # Simulation specifications
    Classic, Modern,

    # Result specifications
    Minimal, Temporal, SpatioTemporal, Network


abstract type ReliabilityMetric end
abstract type SimulationSpec end
abstract type ResultSpec end
abstract type ResultAccumulator{R<:ResultSpec} end
abstract type Result{
    N, # Number of timesteps simulated
    L, # Length of each simulation timestep
    T <: Period, # Units of each simulation timestep
    SS <: SimulationSpec # Type of simulation that produced the result
} end

MeanVariance = Series{
    Number, Tuple{Mean{Float64, EqualWeight}, Variance{Float64, EqualWeight}}
}

include("metrics/metrics.jl")
include("results/results.jl")
include("simulations/simulations.jl")
include("utils.jl")

end
