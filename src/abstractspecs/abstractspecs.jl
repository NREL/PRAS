# Simulation

abstract type SimulationSequentiality end
struct NonSequential <: SimulationSequentiality end
struct Sequential <: SimulationSequentiality end

"""
An abstract parent type for specifying specific simulation methods. When
defining a new type `S where {S <: SimulationSpec}`, you must also define
methods for the following functions:

 - `ismontecarlo`
 - `iscopperplate`
 - `assess!`

Check the documentation for each function for required type signatures.
"""
abstract type SimulationSpec{T<:SimulationSequentiality} end

# Results

"""
An abstract parent type for specifying how results should be stored. When
defining a new type `S where {S <: ResultSpec}, you must also define methods for
the following functions:

 - `accumulator`

Check the documentation for each function for required type signatures.

You must also define the following allied types and their associated methods:

 - `A where {A <: ResultAccumulator}`
 - `R where {R <: Result}`

"""
abstract type ResultSpec end

"""
An abstract parent type for accumulating simulation results. When defining
a new type `A where {A <: ResultAccumulator}`, you must define methods for
the following functions:

 - `savetimestepsample!` - for Monte Carlo simulations
 - `savetimestepresult!` - for time-partitioned analytical solutions
 - `finalize`

Check the documentation for each function for required type signatures.

You must also define the following allied types and their associated methods:

 - `S where {S <: ResultSpec}`
 - `R where {R <: Result}`

"""
abstract type ResultAccumulator{
    S <: SystemModel, # Type of simulated system
    SS <: SimulationSpec # Simulation being used
} end


"""
An abstract parent type for simulation results. When defining a new type
`R where {R <: Result}`, you must define methods for the following functions
/ constructors:

 - `LOLP`
 - `LOLE`
 - `EUE`

Check the documentation for each function for required type signatures. #TODO

You must also define the following allied types and their associated methods:

 - `S where {S <: ResultSpec}`
 - `A where {A <: ResultAccumulator}`

"""
abstract type Result{
    N, # Number of timesteps simulated
    L, # Length of each simulation timestep
    T <: Period, # Units of each simulation timestep
    SS <: SimulationSpec # Type of simulation that produced the result
} end

# Load abstract methods
include("simulation.jl")
include("result.jl")
