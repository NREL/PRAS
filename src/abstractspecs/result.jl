# TODO: Documentation for metrics

# Metrics defined over multiple timesteps
for T in [LOLP, LOLE, EUE] # LOLF would go here too

    # Metric over all timesteps and regions
    (::Type{T})(::R) where {R<:Result} = 
        error("$T(::$R) not yet defined")

    # Metric over all timesteps and specific region
    (::Type{T})(::R, ::AbstractString) where {R<:Result} = 
        error("$T(::$R, region::AbstractString) not defined: $R may not " *
              "support regional results")

    # Metric over specific timestep range and all regions
    (::Type{T})(::R, ::DateTime, ::DateTime) where {R<:Result} =
        error("$T(::$R, start::DateTime, end::DateTime) not defined: $R " *
              "may not support timestep sub-interval results")

    # Metric over specific region and specific timestep range
    (::Type{T})(::R, ::DateTime, ::DateTime, ::AbstractString) where {R<:Result} =
        error("$T(::$R, start::DateTime, end::DateTime, " *
              "region::AbstractString) not defined: $R may not support " *
              "regional timestep sub-interval results")

end

# Metrics defined over single timesteps
for T in [LOLP, EUE]

    # Metric at a specific timestep over all regions
    (::Type{T})(::R, ::DateTime) where {R<:Result} = 
        error("$T(::$R, period::DateTime) not yet defined: $R may not support" *
              "timestep-specific results")

   
    # Metric at a specific timestep and region
    (::Type{T})(::R, ::DateTime, ::AbstractString) where {R<:Result} = 
        error("$T(::$R, period::DateTime, region::AbstractString) " *
              "not yet defined: $R may not support regional " *
              "timestep-specific results")

end

"""

    accumulator(::ExtractionSpec, ::SimulationSpec, ::ResultSpec,
                ::SystemModel, seed::UInt)::ResultAccumulator

Returns a `ResultAccumulator` corresponding to the provided `ResultSpec`.
"""
accumulator(::ExtractionSpec, ::SimulationSpec, ::S,
            ::SystemModel{N,L,T,P,E,V}, seed::UInt
) where {N,L,T,P,E,V,S<:ResultSpec} = 
    error("An `accumulator` method has not been defined for ResultSpec $T")

"""

    update!(::ResultAccumulator, ::NetworkState, t::Int, i::Int)::nothing

Records a simulation sample of supply, demand, and flows from timestep `t`
and simulation `i` in the provided `ResultAccumulator`.

Implementation note: This function should be thread-safe as it will
generally be parallelized across many time periods and/or samples during
simulations. This is commonly achieved by storing results in a
thread-specific temporary storage location in the `ResultAccumulator` struct
and then merging results from all threads during `finalize`.

For sequential simulation methods, results for a single simulation `i`
can be assumed to be generated serially on a single thread.

For nonsequential simulation methods, results for a single timestep `t`
can be assumed to be generated serially on a single thread.
"""
update!(::A, ::SystemOutputStateSample, t::Int, i::Int) where {A <: ResultAccumulator} =
    error("Monte Carlo / sample-based update! has not yet " *
          "been defined for ResultAccumulator $A")

"""

    update!(acc::ResultAccumulator, ::NetworkSolution, t::Int)::nothing

Store analytical (non-sampled) final results for the time period `t`.

Implementation note: This function should be thread-safe as it may
generally be parallelized across time periods during execution. This is
commonly achieved by storing results in a thread-specific temporary storage
location in the `ResultAccumulator` struct and then merging results from all
threads during `finalize`.
"""
update!(::R, ::SystemOutputStateSummary, t::Int) where {R <: ResultAccumulator} =
    error("Analytical / solution-based update! has not yet " *
          "been defined for ResultAccumulator $A")

"""

    finalize(::ExtractionSpec, ::SimulationSpec, ::ResultAccumulator)::Result

Returns a `Result` corresponding to the provided `ResultAccumulator`.
"""
finalize(::A) where {A <: ResultAccumulator} =
    error("finalize not defined for ResultAccumulator $A")

