@reexport module ResourceAdequacy

using MinCostFlows
using ..PRASBase

import Base: -, broadcastable, getindex
import Base.Threads: nthreads, @spawn
import Dates: DateTime, Period
import Decimals: Decimal, decimal
import Distributions: DiscreteNonParametric, probs, support
import OnlineStatsBase: EqualWeight, fit!, Mean, value, Variance
import OnlineStats: Series
import Printf: @sprintf
import Random: AbstractRNG, rand, seed!
import Random123: Philox4x
import StatsBase: mean, std, stderror
import TimeZones: ZonedDateTime, @tz_str

export

    assess,

    # Metrics
    ReliabilityMetric, LOLE, EUE,
    val, stderror,

    # Simulation specifications
    Convolution, SequentialMonteCarlo,

    # Result specifications
    Shortfall, ShortfallSamples, Surplus, SurplusSamples,
    Flow, FlowSamples, Utilization, UtilizationSamples,
    StorageEnergy, StorageEnergySamples,
    GeneratorStorageEnergy, GeneratorStorageEnergySamples,
    GeneratorAvailability, StorageAvailability,
    GeneratorStorageAvailability, LineAvailability,

    # Convenience re-exports
    ZonedDateTime, @tz_str

abstract type ReliabilityMetric end
abstract type SimulationSpec end
abstract type ResultSpec end
abstract type ResultAccumulator{S<:SimulationSpec,R<:ResultSpec} end
abstract type Result{
    N, # Number of timesteps simulated
    L, # Length of each simulation timestep
    T <: Period, # Units of each simulation timestep
} end

MeanVariance = Series{
    Number, Tuple{Mean{Float64, EqualWeight},
                  Variance{Float64, Float64, EqualWeight}}}

include("metrics.jl")
include("results/results.jl")
include("simulations/simulations.jl")
include("utils.jl")

end
