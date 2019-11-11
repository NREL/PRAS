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
