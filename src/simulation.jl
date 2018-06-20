abstract type SimulationSequentiality end
struct NonSequential <: SimulationSequentiality end
struct Sequential <: SimulationSequentiality end

abstract type SimulationSpec{T<:SimulationSequentiality} end

abstract type ReliabilityAssessmentMethod end

abstract type ReliabilityAssessmentResult{N,P<:Period,E<:EnergyUnit,V<:Real} end

include("simulation/copperplate.jl")
include("simulation/networkflow.jl")

function assess(extractionmethod::SinglePeriodExtractionMethod,
                assessmentmethod::ReliabilityAssessmentMethod,
                systemset::SystemDistributionSet)

    # More efficient for copperplate assessment.
    # What to do with this? Preprocess step?
    # systemset_collapsed = collapse(systemset)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> assess(assessmentmethod,
                                extract(extractionmethod, dt, systemset)),
                   dts, batch_size=batchsize)

    return MultiPeriodReliabilityAssessmentResult(dts, results)

end
