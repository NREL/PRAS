abstract type CapacityValuationMethod{
    M<:ReliabilityMetric,
    AM<:ReliabilityAssessmentMethod}
end

include("valuationmethods/utils.jl")
include("valuationmethods/efc.jl")
