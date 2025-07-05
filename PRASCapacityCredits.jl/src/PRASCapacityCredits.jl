module PRASCapacityCredits

import PRASCore.Systems: Generators, PowerUnit, Regions, SystemModel, unitsymbol
import PRASCore.Simulations: assess, SequentialMonteCarlo
import PRASCore.Results: ReliabilityMetric, Result, Shortfall, stderror, val

import Base: minimum, maximum, extrema
import Distributions: ccdf, cdf, Normal

export EFC, ELCC

abstract type CapacityValuationMethod{M<:ReliabilityMetric} end

include("utils.jl")
include("CapacityCreditResult.jl")
include("EFC.jl")
include("ELCC.jl")

end
