"""

   iscopperplate(::SimulationSpec)::Bool

Defines whether the simulation method associated with `SimulationSpec` will
ignore disaggregated region and transmission data. Computational speedups are
generally possible when this is true.
"""
iscopperplate(::S) where {S <: SimulationSpec} = 
    error("iscopperplate not yet defined for SimulationSpec $S")


"""

    assess!(::ResultAccumulator, ::ExtractionSpec,
            ::SimulationSpec, ::SystemModel)

Run a full simulation of `SystemModel` according to `ExtractionSpec` and
`SimulationSpec`, storing the results in `ResultAccumulator`.
"""
assess!(::ResultAccumulator, ::ExtractionSpec, ::S, ::SystemModel
) where {S <: SimulationSpec} =
    error("assess! not yet defined for SimulationSpec $S")

"""

    assess!(::ResultAccumulator, ::SimulationSpec,
            ::SystemInputStateDistribution, t::Int)

Solve a `SystemInputStateDistribution` at timestep `t` of the simulation as
specified by `SimulationSpec`, storing the results in `ResultAccumulator`.
"""
assess!(::ResultAccumulator, ::S, ::SystemInputStateDistribution, t::Int
) where {S <: SimulationSpec} =
    error("assess! not yet defined for SimulationSpec $S")

function assess(extractionspec::ExtractionSpec,
                simulationspec::SimulationSpec{NonSequential},
                resultspec::ResultSpec,
                system::SystemModel,
                seed::UInt=rand(UInt))

    acc = accumulator(extractionspec, simulationspec, resultspec, system, seed)

    #TODO: If storage devices exist, warn that they may be ignored or
    #      treated as firm capacity - need to decide how exactly that
    #      should work first though...

    statedistrs = extract(extractionspec, system, iscopperplate(simulationspec))
    for (t, statedistr) in collect(enumerate(statedistrs))
        assess!(acc, simulationspec, statedistr, t)
    end

    return finalize(acc)

end

function assess(extractionspec::ExtractionSpec,
                simulationspec::SimulationSpec{Sequential},
                resultspec::ResultSpec,
                system::SystemModel,
                seed::UInt=rand(UInt))

    acc = accumulator(extractionspec, simulationspec, resultspec, system, seed)

    for i in 1:simulationspec.nsamples
        assess!(acc, extractionspec, simulationspec, system, i)
    end

    return finalize(acc)

end
