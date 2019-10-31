@testset "SequentialCopperplate" begin

    seed = UInt(1234)
    nstderr_tol = 3
    simspec = SequentialCopperplate(samples=100_000, collapsestorage=true)

    # TODO: Add test case with storage
    assess(simspec, Minimal(), singlenode_stor, seed)

    # Note: These results should be close but not technically identical
    # TODO: Solve sequential probabilities by hand

    # Overall result - singlenode_a
    result_1a = assess(simspec, Minimal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)

    result_1a = assess(simspec, Temporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1a, singlenode_a.timestamps),
                           singlenode_a_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1a, singlenode_a.timestamps),
                           singlenode_a_eues, nstderr_tol))

    # Overall result - singlenode_b
    result_1b = assess(simspec, Minimal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)

    result_1b = assess(simspec, Temporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1b, singlenode_b.timestamps),
                           singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1b, singlenode_b.timestamps),
                           singlenode_b_eues, nstderr_tol))

    # Three-region system
    result_3 = assess(simspec, Minimal(), threenode, seed)
    @test withinrange(LOLE(result_3), threenode_lole_copperplate, nstderr_tol)
    @test withinrange(EUE(result_3), threenode_eue_copperplate, nstderr_tol)

    result_3 = assess(simspec, Temporal(), threenode, seed)
    @test withinrange(LOLE(result_3), threenode_lole_copperplate, nstderr_tol)
    @test withinrange(EUE(result_3), threenode_eue_copperplate, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3, threenode.timestamps),
                           threenode_lolps_copperplate, nstderr_tol))
    @test all(withinrange.(EUE.(result_3, threenode.timestamps),
                           threenode_eues_copperplate, nstderr_tol))

end
