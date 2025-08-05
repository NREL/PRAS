# Augment time units

unitsymbol(T::Type{<:Period}) = string(T)
unitsymbol(::Type{Minute}) = "min"
unitsymbol(::Type{Hour}) = "h"
unitsymbol(::Type{Day}) = "d"
unitsymbol(::Type{Year}) = "y"

unitsymbol_long(::Type{Minute}) = "Minute"
unitsymbol_long(::Type{Hour}) = "Hour"
unitsymbol_long(::Type{Day}) = "Day"
unitsymbol_long(::Type{Year}) = "Year"

conversionfactor(F::Type{<:Period}, T::Type{<:Period}) =
    conversionfactor(F, Hour) * conversionfactor(Hour, T)

conversionfactor(::Type{Minute}, ::Type{Hour}) = 1 / 60
conversionfactor(::Type{Hour}, ::Type{Minute}) = 60

conversionfactor(::Type{Hour}, ::Type{Hour}) = 1

conversionfactor(::Type{Hour}, ::Type{Day}) = 1 / 24
conversionfactor(::Type{Day}, ::Type{Hour}) = 24

timeunits = Dict(
    unitsymbol(T) => T
    for T in [Minute, Hour, Day, Year])

# Define power units

abstract type PowerUnit end
struct kW <: PowerUnit end
struct MW <: PowerUnit end
struct GW <: PowerUnit end
struct TW <: PowerUnit end

unitsymbol(T::Type{<:PowerUnit}) = string(T)
unitsymbol(::Type{kW}) = "kW"
unitsymbol(::Type{MW}) = "MW"
unitsymbol(::Type{GW}) = "GW"
unitsymbol(::Type{TW}) = "TW"

conversionfactor(F::Type{<:PowerUnit}, T::Type{<:PowerUnit}) =
    conversionfactor(F, MW) * conversionfactor(MW, T)

conversionfactor(::Type{kW}, ::Type{MW}) = 1 / 1000
conversionfactor(::Type{MW}, ::Type{kW}) = 1000

conversionfactor(::Type{MW}, ::Type{MW}) = 1

conversionfactor(::Type{MW}, ::Type{GW}) = 1 / 1000
conversionfactor(::Type{GW}, ::Type{MW}) = 1000

conversionfactor(::Type{MW}, ::Type{TW}) = 1 / 1_000_000
conversionfactor(::Type{TW}, ::Type{MW}) = 1_000_000

powerunits = Dict(
    unitsymbol(T) => T
    for T in [kW, MW, GW, TW])

# Define energy units

abstract type EnergyUnit end
struct kWh <: EnergyUnit end
struct MWh <: EnergyUnit end
struct GWh <: EnergyUnit end
struct TWh <: EnergyUnit end

unitsymbol(T::Type{<:EnergyUnit}) = string(T)
unitsymbol(::Type{kWh}) = "kWh"
unitsymbol(::Type{MWh}) = "MWh"
unitsymbol(::Type{GWh}) = "GWh"
unitsymbol(::Type{TWh}) = "TWh"

subunits(::Type{kWh}) = (kW, Hour)
subunits(::Type{MWh}) = (MW, Hour)
subunits(::Type{GWh}) = (GW, Hour)
subunits(::Type{TWh}) = (TW, Hour)

energyunits = Dict(
    unitsymbol(T) => T
    for T in [kWh, MWh, GWh, TWh])

function conversionfactor(F::Type{<:EnergyUnit}, T::Type{<:EnergyUnit})

    from_power, from_time = subunits(F)
    to_power, to_time = subunits(T)

    powerconversion = conversionfactor(from_power, to_power)
    timeconversion = conversionfactor(from_time, to_time)

    return powerconversion * timeconversion

end

function conversionfactor(
    L::Int, T::Type{<:Period}, P::Type{<:PowerUnit}, E::Type{<:EnergyUnit})
    to_power, to_time = subunits(E)
    powerconversion = conversionfactor(P, to_power)
    timeconversion = conversionfactor(T, to_time)
    return powerconversion * timeconversion * L
end

function conversionfactor(
    L::Int, T::Type{<:Period}, E::Type{<:EnergyUnit}, P::Type{<:PowerUnit})
    from_power, from_time = subunits(E)
    powerconversion = conversionfactor(from_power, P)
    timeconversion = conversionfactor(from_time, T)
    return powerconversion * timeconversion / L
end

powertoenergy(
    p::Real, P::Type{<:PowerUnit},
    L::Real, T::Type{<:Period},
    E::Type{<:EnergyUnit}) = p*conversionfactor(L, T, P, E)

energytopower(
    e::Real, E::Type{<:EnergyUnit},
    L::Real, T::Type{<:Period},
    P::Type{<:PowerUnit}) = e*conversionfactor(L, T, E, P)

