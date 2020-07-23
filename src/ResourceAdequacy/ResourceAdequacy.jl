@reexport module ResourceAdequacy

using MinCostFlows
using ..PRASBase

import Base: -, broadcastable
import Base.Threads: nthreads, @spawn
import Dates: DateTime, Period
import Decimals: Decimal, decimal
import Distributions: DiscreteNonParametric, probs, support
import OnlineStatsBase: EqualWeight, fit!, Mean, value, Variance
import OnlineStats: Series
import Printf: @sprintf
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x
import StatsBase: stderror
import TimeZones: ZonedDateTime, @tz_str

export

    assess,

    # Metrics
    ReliabilityMetric, LOLP, LOLE, EUE,
    ExpectedInterfaceFlow, ExpectedInterfaceUtilization,
    val, stderror,

    # Simulation specifications
    Convolution, SequentialMonteCarlo,

    # Result specifications
    Minimal, Temporal, SpatioTemporal, Network, Debug,

    # Convenience re-exports
    ZonedDateTime, @tz_str

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
    Number, Tuple{Mean{Float64, EqualWeight},
                  Variance{Float64, Float64, EqualWeight}}}

include("metrics/metrics.jl")
include("results/results.jl")
include("simulations/simulations.jl")
include("utils.jl")

end
