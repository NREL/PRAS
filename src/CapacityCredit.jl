module CapacityCredit

import Distributions: ccdf, Normal
import PRASBase: Generators, Regions, SystemModel, unitsymbol
import ResourceAdequacy: assess, ResultSpec, ReliabilityMetric,
                         SimulationSpec, stderror, val

export EFC, ELCC

abstract type CapacityValuationMethod{M<:ReliabilityMetric} end

include("utils.jl")
include("EFC.jl")
include("ELCC.jl")

end # module
