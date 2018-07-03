abstract type AbstractReliabilityResult{
    P <: PowerUnit, # Units for reported power values
    E <: EnergyUnit, # Units for reported energy values
    V <: Real, # Numeric type of value data
    SS <: SimulationSpec # Type of simulation that produced the result
} end


"""
Types inheriting from `SinglePeriodReliabilityResult` should define:
 - LOLP and EUE constructor methods
"""
abstract type SinglePeriodReliabilityResult{
    N, # Length of the single simulation time interval
    T <: Period, # Units for the simulation interval duration
    P <: PowerUnit, # Units for reported power values
    E <: EnergyUnit, # Units for reported energy values
    V <: Real, # Numeric type of value data
    SS <: SimulationSpec # Type of simulation that produced the result
} <: AbstractReliabilityResult{P,E,V,SS} end


"""
Types inheriting from `MultiPeriodReliabilityResult` should define at least
one of the following sets of methods.

Timestamp indexing:
 - a `timestamps` method to retreive a `Vector{DateTime}` of spanned
   time periods
 - a `Base.getindex` method for looking up the `SinglePeriodResult`
   corresponding to a DateTime

Metric constructors:
 - `LOLE` and `EUE` constructor methods (default methods that use timestamp
   indexing and SinglePeriodResult `LOLP`/`EUE` constructors are available)
"""
abstract type MultiPeriodReliabilityResult{
    N1, # Length of the single simulation time interval
    T1 <: Period, # Units for one simulation interval duration
    N2, # Length of the total simulation duration
    T2 <: Period, # Units for the total simulation duration
    P <: PowerUnit, # Units for reported power values
    E <: EnergyUnit, # Units for reported power values
    V <: Real, # Numeric type of value data
    ES <: ExtractionSpec, # Type of extraction that produced interval distibutions
    SS <: SimulationSpec # Type of simulation that produced the result
} <: AbstractReliabilityResult{P,E,V,SS} end

LOLE(x::MultiPeriodReliabilityResult) = LOLE([LOLP(x[dt]) for dt in timestamps(x)])
EUE(x::MultiPeriodReliabilityResult) = EUE([EUE(x[dt]) for dt in timestamps(x)])

include("results/minimal.jl")
include("results/network.jl")
