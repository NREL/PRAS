abstract type PowerUnit end
struct MW <: PowerUnit end
struct GW <: PowerUnit end

abstract type EnergyUnit end
struct MWh <: EnergyUnit end
struct GWh <: EnergyUnit end
struct TWh <: EnergyUnit end

unitsymbol(T::Type{<:PowerUnit}) = string(T)
unitsymbol(::Type{MW}) = "MW"
unitsymbol(::Type{GW}) = "GW"

unitsymbol(T::Type{<:EnergyUnit}) = string(T)
unitsymbol(::Type{MWh}) = "MWh"
unitsymbol(::Type{GWh}) = "GWh"
unitsymbol(::Type{TWh}) = "TWh"

unitsymbol(T::Type{<:Period}) = string(T)
unitsymbol(::Type{Minute}) = "min"
unitsymbol(::Type{Hour}) = "h"
unitsymbol(::Type{Day}) = "d"
unitsymbol(::Type{Year}) = "y"

powertoenergy(
    p::Real, P::Type{<:PowerUnit},
    L::Real, T::Type{<:Period},
    E::Type{<:EnergyUnit}) = p*powertoenergy(P,L,T,E)

energytopower(
    e::Real, E::Type{<:EnergyUnit},
    L::Real, T::Type{<:Period},
    P::Type{<:PowerUnit}) = e*energytopower(E,L,T,P)

#TODO: Need to generalize all of this. Maybe define all relationships
#      in terms of conversions to a common set of units (MW, MWh, Hour?)
#      and ship all conversions through those?

powertoenergy(::Type{MW}, L::Real, ::Type{Hour}, ::Type{MWh}) = L
powertoenergy(::Type{MW}, L::Real, ::Type{Minute}, ::Type{MWh}) = L/60

energytopower(::Type{MWh}, L::Real, ::Type{Hour}, ::Type{MW}) = 1/L
energytopower(::Type{MWh}, L::Real, ::Type{Minute}, ::Type{MW}) = 60/L
