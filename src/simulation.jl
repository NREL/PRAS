include("simulation/copperplate.jl")
include("simulation/networkflow.jl")

function assess(extractionspec::ExtractionSpec,
                simulationspec::SimulationSpec{NonSequential},
                resultspec::ResultSpec,
                systemset::SystemDistributionSet)

    # More efficient for copperplate assessment.
    # What to do with this? Preprocess step?
    # systemset_collapsed = collapse(systemset)

    dts = unique(systemset.timestamps)
    batchsize = ceil(Int, length(dts)/nworkers()/2)
    println("Starting the pmap process.")
    results = pmap(dt -> assess(simulationspec,
                                resultspec,
                                extract(extractionspec, dt, systemset)),
                   dts, batch_size=batchsize)
    println("Finished the pmap process.")
    return aggregator(resultspec)(dts, results, extractionspec)

end
