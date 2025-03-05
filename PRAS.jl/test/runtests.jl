using PRAS
using Test

sys = PRAS.rts_gmlc()

sf, = assess(sys, SequentialMonteCarlo(samples=100), Shortfall())

eue = EUE(sf)
lole = LOLE(sf)
neue = NEUE(sf)

@test val(eue) isa Float64
@test stderror(eue) isa Float64
@test val(neue) isa Float64
@test stderror(neue) isa Float64
