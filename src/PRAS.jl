module PRAS

using Reexport

const PRAS_VERSION = "v0.6.0"

include("PRASBase/PRASBase.jl")
include("ResourceAdequacy/ResourceAdequacy.jl")
include("CapacityCredit/CapacityCredit.jl")

import .PRASBase: rts_gmlc, toymodel

end
