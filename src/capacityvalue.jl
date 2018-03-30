abstract type CapacityValuationMethod{
    M<:ReliabilityMetric,
    AM<:ReliabilityAssessmentMethod}
end

include("capacityvalue/utils.jl")
include("capacityvalue/efc.jl")
