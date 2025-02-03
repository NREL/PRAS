struct RegionResult
    name::String
    eue::EUE_Result
    lole::LOLE_Result
    neue::Float64
    load::Vector{Float64}
    peak_load::Float64
    capacity::Dict{String,Vector{Float64}}
    shortfall_mean::Vector{Float64}
    surplus_mean::Vector{Float64}
    storage_SoC::Vector{Float64}
    shortfall_ts_idx::Vector{Int64}
end

struct System_Result
    num_samples::Int64
    type_params::TypeParams
    timestamps::Vector{ZonedDateTime}
    eue::EUE_Result
    lole::LOLE_Result
    region_results::Vector{RegionResult}
end

struct EUE_Result
    mean::Float64
    stderror::Float64
end

struct LOLE_Result
    mean::Float64
    stderror::Float64
end

struct TypeParams
    N::Int64
    L::Int64
    T::String
    P::String
    E::String
end