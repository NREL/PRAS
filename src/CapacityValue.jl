module CapacityValue

using Distributions

import ResourceAdequacy
const RA = ResourceAdequacy

export EFC

abstract type CapacityValuationMethod end

include("utils.jl")
include("EFC.jl")

end # module
