struct RegionResult
    name::String
    timesteps::Int64
    load::Vector{Float64}

    # Inner Constructors & Checks
    function Region(name, timesteps, load = zeros(Float64, timesteps))
        length(load) == timesteps || error(
            "The length of the region $(name) load time series data is $(length(load)) but it should be
             equal to PRAS timesteps ($(timesteps))",
        )

        all(load .>= 0.0) ||
            error("Check for negative values in region $(name) load time series data.")

        return new(name, timesteps, load)
    end
end

struct System_Result
    num_samples::Int64
    timesteps::Int64
    load::Vector{Float64}
    pras_meta

    # Inner Constructors & Checks
    function Region(name, timesteps, load = zeros(Float64, timesteps))
        length(load) == timesteps || error(
            "The length of the region $(name) load time series data is $(length(load)) but it should be
             equal to PRAS timesteps ($(timesteps))",
        )

        all(load .>= 0.0) ||
            error("Check for negative values in region $(name) load time series data.")

        return new(name, timesteps, load)
    end
end

struct EUE_Result
    num_samples::Int64
    timesteps::Int64
    load::Vector{Float64}

    # Inner Constructors & Checks
    function Region(name, timesteps, load = zeros(Float64, timesteps))
        length(load) == timesteps || error(
            "The length of the region $(name) load time series data is $(length(load)) but it should be
             equal to PRAS timesteps ($(timesteps))",
        )

        all(load .>= 0.0) ||
            error("Check for negative values in region $(name) load time series data.")

        return new(name, timesteps, load)
    end
end

struct TypeParams
    N::Int64
    L::
    T::
    P::
    E::
end