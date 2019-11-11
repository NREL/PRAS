# Simulation

"""
An abstract parent type for specifying specific simulation methods. When
defining a new type `S where {S <: SimulationSpec}`, you must also define
methods for the following functions:

 - `assess`

Check the documentation for each function for required type signatures.
"""
abstract type SimulationSpec end

"""
An abstract parent type for holding cached data and memory allocation
during simulations. When defining a new type `S where {S <: SimulationCache}`,
you must also define methods for the following functions:

 - `cache`

Check the documentation for each function for required type signatures.
"""
abstract type SimulationCache{
    N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,SS<:SimulationSpec} end

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

 - `update!`
 - `finalize`

Check the documentation for each function for required type signatures.

You must also define the following allied types and their associated methods:

 - `S where {S <: ResultSpec}`
 - `R where {R <: Result}`

"""
abstract type ResultAccumulator{R<:ResultSpec,S<:SimulationSequentiality} end


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
