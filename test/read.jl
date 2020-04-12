@testset "Read from disk" begin
    toy = SystemModel(dirname(@__FILE__) * "/toymodel.pras")
    rts = SystemModel(dirname(@__FILE__) * "/rts.pras")
    # TODO: Verify systems accurately depicted
end
