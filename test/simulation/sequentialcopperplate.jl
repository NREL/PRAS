@testset "SequentialCopperPlate" begin

    seed = UInt(1234)
    nstderr_tol = 3


    # These results should be close but not technically identical
    # TODO: Solve sequential probabilities by hand
    # TODO: Add test case with storage

    # TODO: Implement and test Temporal sequential accumulator

    # Overall result - singlenode_a
    result_1a = assess(Backcast(), SequentialCopperplate(100_000), Minimal(),
                        singlenode_a, seed)
    @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)

    # Overall result - singlenode_b
    result_1b = assess(Backcast(), SequentialCopperplate(100_000), Minimal(),
                        singlenode_b, seed)
    @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)

    # Three-region system
    result_3 = assess(Backcast(), SequentialCopperplate(100_000), Minimal(),
                       threenode, seed)
    @test withinrange(LOLE(result_3), threenode_lole_copperplate, nstderr_tol)
    @test withinrange(EUE(result_3), threenode_eue_copperplate, nstderr_tol)

end
