abstract type EnergyUnit end
type MWh <: EnergyUnit end
type GWh <: EnergyUnit end
type TWh <: EnergyUnit end

unitsymbol(T::Type{<:EnergyUnit}) = string(T)
unitsymbol(T::Type{MWh}) = "MWh"
unitsymbol(T::Type{GWh}) = "GWh"
unitsymbol(T::Type{TWh}) = "TWh"

unitsymbol(x::Period) = string(Period)
unitsymbol(::Type{Hour}) = "h"
unitsymbol(::Type{Day}) = "d"
unitsymbol(::Type{Year}) = "y"
