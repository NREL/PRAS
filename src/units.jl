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

#TODO: Need to generalize all of this. Maybe define all relationships
#      in terms of conversions to a common set of units (MW, MWh, Hour?)
#      and ship all conversions through those?

powertoenergy(::Type{MWh}, p::Real, ::Type{MW}, n::Real, ::Type{Hour})   = n*p
powertoenergy(::Type{MWh}, p::Real, ::Type{MW}, n::Real, ::Type{Minute}) = n*p/60

energytopower(::Type{MW}, e::Real, ::Type{MWh}, n::Real, ::Type{Hour})   = e/n
energytopower(::Type{MW}, e::Real, ::Type{MWh}, n::Real, ::Type{Minute}) = e/n*60
