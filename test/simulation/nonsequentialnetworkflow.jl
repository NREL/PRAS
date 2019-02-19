@testset "NonSequentialNetworkFlow" begin

    seed = UInt(1234)
    nstderr_tol = 3

    # Single-region system A
    lole = 0.355
    lolps = [] # TODO
    eue = 1.59
    eues = [] # TODO

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), eue, nstderr_tol)
    @test withinrange(LOLE(result_1ab, "Region"), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab, "Region"), eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), eue, nstderr_tol)
    @test_broken all(withinrange.(LOLP.(result_1ab, threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1ab, threenode.timestamps),
                           eues, nstderr_tol))

    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), eue, nstderr_tol)
    @test withinrange(LOLE(result_1ab, "Region"), lole, nstderr_tol)
    @test withinrange(EUE(result_1ab, "Region"), eue, nstderr_tol)
    @test_broken all(withinrange.(LOLP.(result_1ab, threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1ab, threenode.timestamps),
                           eues, nstderr_tol))
    @test_broken all(withinrange.(LOLP.(result_1ab, "Region", threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1ab, "Region", threenode.timestamps),
                           eues, nstderr_tol))

    # Single-region system B
    lole = 0.96
    eue = 7.11
    lolps = [] # TODO
    eues = [] # TODO

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), eue, nstderr_tol)
    @test_broken all(withinrange.(LOLP.(result_1bb, threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1bb, threenode.timestamps),
                           eues, nstderr_tol))

    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), eue, nstderr_tol)
    @test_broken all(withinrange.(LOLP.(result_1bb, threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1bb, threenode.timestamps),
                           eues, nstderr_tol))
    @test_broken all(withinrange.(LOLP.(result_1bb, "Region", threenode.timestamps),
                           lolps, nstderr_tol))
    @test_broken all(withinrange.(EUE.(result_1bb, "Region", threenode.timestamps),
                           eues, nstderr_tol))

    println("\nThree-region system")
    lole = 1.3756
    lolps = [0.14707, 0.40951, 0.40951, 0.40951]
    eue = 12.12885
    eues = [1.75783, 3.13343, 2.87563, 4.36196]

    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Minimal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), eue, nstderr_tol)

    println("Spatial:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Spatial(), threenode, seed)
    @test withinrange(LOLE(result_3mb), lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), eue, nstderr_tol)
    # TODO:  Test spatially-disaggregated results
    display(hcat(threenode.regions,
                 LOLE.(result_3mb, threenode.regions),
                 EUE.(result_3mb, threenode.regions)))
    println()

    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Temporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           eues, nstderr_tol))

    println("SpatioTemporal:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        SpatioTemporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           eues, nstderr_tol))

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
