@reexport module CapacityCredit

import Base: minimum, maximum, extrema
import Distributions: ccdf, Normal
import ..PRASBase: Generators, PowerUnit, Regions, SystemModel, unitsymbol
import ..ResourceAdequacy: assess, ReliabilityMetric, Result, Shortfall,
                           SimulationSpec, stderror, val

export EFC, ELCC

abstract type CapacityValuationMethod{M<:ReliabilityMetric} end

include("utils.jl")
include("CapacityCreditResult.jl")
include("EFC.jl")
include("ELCC.jl")

end
