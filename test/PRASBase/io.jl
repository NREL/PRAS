@testset "Roundtrip .pras files to/from disk" begin

    # TODO: Verify systems accurately depicted?
    path = dirname(@__FILE__)

    toy = PRAS.toymodel()
    savemodel(toy, path * "/toymodel2.pras")
    toy2 = SystemModel(path * "/toymodel2.pras")
    @test toy == toy2

    rts = PRAS.rts_gmlc()
    savemodel(rts, path * "/rts2.pras")
    rts2 = SystemModel(path * "/rts2.pras")
    @test rts == rts2
end
