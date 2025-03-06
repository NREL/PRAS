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

struct EUEResult
    mean::Float64
    stderror::Float64
end

function EUEResult(shortfall::ShortfallResult; region::Union{Nothing, String} = nothing)

    eue = (region === nothing) ? EUE(shortfall) :  EUE(shortfall, region)
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

    lole = (region === nothing) ?  LOLE(shortfall) : LOLE(shortfall, region)
    return LOLEResult(
        lole.lole.estimate,
        lole.lole.standarderror,
    )
end

struct NEUEResult
    mean::Float64
    stderror::Float64
end

function NEUEResult(shortfall::ShortfallResult; region::Union{Nothing, String} = nothing)

    neue = (region === nothing) ? NEUE(shortfall) :  NEUE(shortfall, region)
    return NEUEResult(
        neue.neue.estimate,
        neue.neue.standarderror,
    )
end

struct RegionResult
    name::String
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    load::Vector{Int64}
    peak_load::Float64
    capacity::Dict{String,Vector{Int64}}
    shortfall_mean::Vector{Float64}
    shortfall_timestamps::Vector{ZonedDateTime}
end

struct SystemResult
    num_samples::Int64
    type_params::TypeParams
    timestamps::Vector{ZonedDateTime}
    eue::EUEResult
    lole::LOLEResult
    neue::NEUEResult
    region_results::Vector{RegionResult}
end

# Define structtypes for different structs defined above
StructType(::Type{TypeParams}) = Struct()
StructType(::Type{EUEResult}) = Struct()
StructType(::Type{NEUEResult}) = Struct()
StructType(::Type{LOLEResult}) = Struct()
StructType(::Type{RegionResult}) = OrderedStruct()
StructType(::Type{SystemResult}) = OrderedStruct()