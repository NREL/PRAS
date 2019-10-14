"""

   iscopperplate(::SimulationSpec)::Bool

Defines whether the simulation method associated with `SimulationSpec` will
ignore disaggregated region and transmission data. Computational speedups are
generally possible when this is true.
"""
iscopperplate(::S) where {S <: SimulationSpec} = 
    error("iscopperplate not yet defined for SimulationSpec $S")

"""

    cache(::SimulationSpec, ::SystemModel, seed::UInt)

Preallocate a memory cache to be used when simulating `SystemModel` according
to `SimulationSpec`, with random seed `seed`.
"""
cache(::S, ::SystemModel, ::UInt) where {S <: SimulationSpec} =
    error("cache not yet defined for SimulationSpec $S")

"""

    assess!(::ResultAccumulator, ::SimulationSpec, ::SystemModel)

Run a full simulation of `SystemModel` according to
`SimulationSpec`, storing the results in `ResultAccumulator`.
"""
assess!(::ResultAccumulator, ::S, ::SystemModel
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

function assess(simulationspec::SimulationSpec{NonSequential},
                resultspec::ResultSpec,
                system::SystemModel{N},
                seed::UInt=rand(UInt)) where {N}

    cch = cache(simulationspec, system, seed)
    acc = accumulator(NonSequential, resultspec, system)

    nstors = length(system.storages)
    ngenstors = length(system.generatorstorages)

    if nstors + ngenstors > 0
        resources = String[]
        nstors > 0 && push!(resources, "$nstors Storage")
        ngenstors > 0 && push!(resources, "$ngenstors GeneratorStorage")
        @warn "$simulationspec is a non-sequential simulation method. " *
              "The system's " * join(resources, " and ") * " resources " *
              "will be ignored in the assessment."
    end

    Threads.@threads for t in 1:N 
        assess!(cch, acc, t)
    end

    return finalize(cch, acc)

end

function assess(simulationspec::SimulationSpec{Sequential},
                resultspec::ResultSpec,
                system::SystemModel,
                seed::UInt=rand(UInt))

    cch = cache(simulationspec, system, seed)
    acc = accumulator(Sequential, resultspec, system)

    Threads.@threads for i in 1:simulationspec.nsamples
        assess!(cch, acc, i)
    end

    return finalize(cch, acc)

end
