@testset "NonSequentialNetworkFlow" begin

    seed = UInt(12345)
    nstderr_tol = 3

    # Single-region system A
    timestampcol = singlenode_a.timestamps

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
    @test withinrange(LOLE(result_1ab, "Region"), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab, "Region"), singlenode_a_eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1ab, timestampcol),
                           singlenode_a_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1ab, timestampcol),
                           singlenode_a_eues, nstderr_tol))

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
    @test withinrange(LOLE(result_1ab, "Region"), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab, "Region"), singlenode_a_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1ab, timestampcol),
                           singlenode_a_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1ab, timestampcol),
                           singlenode_a_eues, nstderr_tol))
    @test all(withinrange.(LOLP.(result_1ab, "Region", timestampcol),
                           singlenode_a_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1ab, "Region", timestampcol),
                           singlenode_a_eues, nstderr_tol))

    # Single-region system B
    timestampcol = singlenode_b.timestamps

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), singlenode_b_eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1bb, timestampcol),
                           singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, timestampcol), # Fails?
                           singlenode_b_eues, nstderr_tol))

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1bb, timestampcol),
                           singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, timestampcol), # Fails?
                           singlenode_b_eues, nstderr_tol))
    @test all(withinrange.(LOLP.(result_1bb, "Region", timestampcol),
                           singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, "Region", timestampcol), # Fails?
                           singlenode_b_eues, nstderr_tol))

    println("\nThree-region system")

    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Minimal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)

    println("Spatial:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Spatial(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    # TODO:  Test spatially-disaggregated results
    display(hcat(threenode.regions,
                 LOLE.(result_3mb, threenode.regions),
                 EUE.(result_3mb, threenode.regions)))
    println()

    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Temporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           threenode_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           threenode_eues, nstderr_tol))

    println("SpatioTemporal:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        SpatioTemporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           threenode_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           threenode_eues, nstderr_tol))

    # TODO:  Test spatially-disaggregated results
    println("SpatioTemporal LOLPs:")
    regionsrow = reshape(threenode.regions, 1, :)
    timestampcol = collect(threenode.timestamps)
    display(
        vcat(
            hcat("", regionsrow),
            hcat(threenode.timestamps,
                 LOLP.(result_3mb, regionsrow, timestampcol))
    )); println()

    println("SpatioTemporal EUEs:")
    display(
        vcat(
            hcat("", regionsrow),
            hcat(threenode.timestamps,
                 EUE.(result_3mb, regionsrow, timestampcol))
    )); println()

end
