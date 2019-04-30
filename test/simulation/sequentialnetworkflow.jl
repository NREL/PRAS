@testset "SequentialNetworkFlow" begin

    seed = UInt(2345)
    nstderr_tol = 3

    # TODO: More test cases with storage
    @time assess(Backcast(), SequentialNetworkFlow(10), Minimal(), singlenode_stor, seed)

    # Single-region system A
    timestampcol = collect(singlenode_a.timestamps)

    result_1ab =
        assess(Backcast(), SequentialNetworkFlow(100_000), Minimal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), SequentialNetworkFlow(100_000), Spatial(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
    @test withinrange(LOLE(result_1ab, "Region"), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab, "Region"), singlenode_a_eue, nstderr_tol)

    result_1ab =
        assess(Backcast(), SequentialNetworkFlow(100_000), Temporal(), singlenode_a, seed)
    @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
    @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)

    @test all(withinrange.(LOLP.(result_1ab, timestampcol),
                           singlenode_a_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1ab, timestampcol),
                           singlenode_a_eues, nstderr_tol))

    result_1ab =
        assess(Backcast(), SequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_a, seed)
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

    result_1ab =
        assess(Backcast(), SequentialNetworkFlow(100_000), Network(), singlenode_a, seed)
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
    @test length(result_1ab.flows) == 0
    @test length(result_1ab.utilizations) == 0

    # Single-region system B
    timestampcol = collect(singlenode_b.timestamps)

    result_1bb =
        assess(Backcast(), SequentialNetworkFlow(100_000), Minimal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), SequentialNetworkFlow(100_000), Spatial(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), singlenode_b_eue, nstderr_tol)

    result_1bb =
        assess(Backcast(), SequentialNetworkFlow(100_000), Temporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1bb, timestampcol),
                           singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, timestampcol),
                           singlenode_b_eues, nstderr_tol))

    result_1bb =
        assess(Backcast(), SequentialNetworkFlow(100_000), SpatioTemporal(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1bb, timestampcol),
              singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, timestampcol),
                           singlenode_b_eues, nstderr_tol))
    @test all(withinrange.(LOLP.(result_1bb, "Region", timestampcol),
                           reshape(singlenode_b_lolps, :, 1), nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, "Region", timestampcol),
                           reshape(singlenode_b_eues, :, 1), nstderr_tol))

    result_1bb =
        assess(Backcast(), SequentialNetworkFlow(100_000), Network(), singlenode_b, seed)
    @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
    @test withinrange(LOLE(result_1bb, "Region"), singlenode_b_lole, nstderr_tol)
    @test withinrange(EUE(result_1bb, "Region"), singlenode_b_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_1bb, timestampcol),
              singlenode_b_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, timestampcol),
                           singlenode_b_eues, nstderr_tol))
    @test all(withinrange.(LOLP.(result_1bb, "Region", timestampcol),
                           reshape(singlenode_b_lolps, :, 1), nstderr_tol))
    @test all(withinrange.(EUE.(result_1bb, "Region", timestampcol),
                           reshape(singlenode_b_eues, :, 1), nstderr_tol))
    @test length(result_1bb.flows) == 0
    @test length(result_1bb.utilizations) == 0

    println("\nThree-region system")
    regionsrow = reshape(threenode.regions, 1, :)
    timestampcol = collect(threenode.timestamps)

    result_3mb = assess(Backcast(), SequentialNetworkFlow(100_000),
                        Minimal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)

    println("Spatial:")
    result_3mb = assess(Backcast(), SequentialNetworkFlow(100_000),
                        Spatial(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    # TODO:  Test spatially-disaggregated results
    display(hcat(threenode.regions,
                 LOLE.(result_3mb, threenode.regions),
                 EUE.(result_3mb, threenode.regions)))
    println()

    result_3mb = assess(Backcast(), SequentialNetworkFlow(100_000),
                        Temporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           threenode_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           threenode_eues, nstderr_tol))

    # SpatioTemporal
    println("SpatioTemporal")
    result_3mb = assess(Backcast(), SequentialNetworkFlow(100_000),
                        SpatioTemporal(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           threenode_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           threenode_eues, nstderr_tol))

    @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,1)), 0.1, nstderr_tol)
    @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,2)), 0.1, nstderr_tol)

    # TODO:  Test spatially-disaggregated results
    println("SpatioTemporal LOLPs:")
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

    println("\nNetwork")
    result_3mb = assess(Backcast(), SequentialNetworkFlow(100_000),
                        Network(), threenode, seed)
    @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
    @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
    @test all(withinrange.(LOLP.(result_3mb, threenode.timestamps),
                           threenode_lolps, nstderr_tol))
    @test all(withinrange.(EUE.(result_3mb, threenode.timestamps),
                           threenode_eues, nstderr_tol))

    @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,1)), 0.1, nstderr_tol)
    @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,2)), 0.1, nstderr_tol)

    println("Network ExpectedInterfaceFlows:")
    interfacenamesrow = reshape([(threenode.regions[from], threenode.regions[to])
                             for (from, to) in threenode.interfaces],
                            1, :)
    interfacesrow = reshape(threenode.interfaces, 1, :)
    timestampcol = collect(threenode.timestamps)
    display(
        vcat(
            hcat("", interfacenamesrow),
            hcat(threenode.timestamps,
                 ExpectedInterfaceFlow.(result_3mb, interfacesrow, timestampcol))
    )); println()

    println("Network ExpectedInterfaceUtilizations:")
    display(
        vcat(
            hcat("", interfacenamesrow),
            hcat(threenode.timestamps,
                 ExpectedInterfaceUtilization.(result_3mb, interfacesrow, timestampcol))
    )); println()

end
