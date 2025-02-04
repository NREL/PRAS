# PRAS SystemModel Type Parameters
struct TypeParams
    N::Int64
    L::Int64
    T::String
    P::String
    E::String
end

function TypeParams(pras_sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}
    return TypeParams(
        N,
        L,
        unitsymbol(T),
        unitsymbol(P),
        unitsymbol(E),
    )
end

# EUE Result
struct EUEResult
    mean::Float64
    stderror::Float64
end

function EUEResult(shortfall::ShortfallResult; region::Union{Nothing, String} = nothing)
    eue = 
    if (region === nothing)
        EUE(shortfall)
    else
        EUE(shortfall, region)
    end
    return EUEResult(
        eue.eue.estimate,
        eue.eue.standarderror,
    )
end

struct LOLEResult
    mean::Float64
    stderror::Float64
end

function LOLEResult(shortfall::ShortfallResult; region::Union{Nothing, String} = nothing) 
    lole = 
    if (region === nothing)
        LOLE(shortfall)
    else
        LOLE(shortfall, region)
    end
    return LOLEResult(
        lole.lole.estimate,
        lole.lole.standarderror,
    )
end

struct RegionResult
    name::String
    eue::EUE_Result
    lole::LOLE_Result
    neue::Float64
    load::Vector{Int64}
    peak_load::Float64
    capacity::Dict{String,Vector{Int64}}
    shortfall_mean::Vector{Float64}
    surplus_mean::Vector{Float64}
    storage_SoC::Vector{Float64}
    shortfall_ts_idx::Vector{Int64}
end

function neue(shortfall::ShortfallResult, pras_sys::SystemModel; region::Union{Nothing, String} = nothing)
    eue_result = EUEResult(shortfall, region = region)
    eue = eue_result.mean
    load = 
    if (region === nothing)
        sum(pras_sys.regions.load)
    else
        sum(pras_sys.regions.load[findfirst(pras_sys.regions.names .== region),:])
    end
    
    return 1e6*(eue/load) #returns in ppm
end

struct SystemResult
    num_samples::Int64
    type_params::TypeParams
    timestamps::Vector{ZonedDateTime}
    eue::EUE_Result
    lole::LOLE_Result
    region_results::Vector{RegionResult}
end

