include("simulation/copperplate.jl")
include("simulation/networkflow.jl")

function assess(extractionspec::SinglePeriodExtractionMethod,
                simulationspec::SimulationSpec{NonSequential},
                resultspec::AbstractResultSpec,
                systemset::SystemDistributionSet)

    # More efficient for copperplate assessment.
    # What to do with this? Preprocess step?
    # systemset_collapsed = collapse(systemset)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers())
    results = pmap(dt -> assess(simulationspec,
                                extract(extractionspec, dt, systemset)),
                   dts, batch_size=batchsize)

    return MultiPeriodMinimalResult(dts, results)

end
