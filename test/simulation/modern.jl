@testset "Modern" begin

    @testset "DispatchProblem" begin

    end

    seed = UInt(2345)
    nstderr_tol = 3
    simspec = Modern(samples=100_000)

    timestampcol_a = collect(singlenode_a.timestamps)
    timestampcol_b = collect(singlenode_b.timestamps)
    timestampcol_3 = collect(threenode.timestamps)
    regionsrow = reshape(threenode.regions.names, 1, :)

    @testset "Minimal Result" begin

        # TODO: More test cases with storage
        assess(Modern(samples=10), Minimal(), singlenode_stor)

        # Single-region system A
        result_1a = assess(simspec, Minimal(), singlenode_a)
        @test withinrange(LOLE(result_1a), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1a), singlenode_a_eue, nstderr_tol)

        # Single-region system B
        result_1b = assess(simspec, Minimal(), singlenode_b)
        @test withinrange(LOLE(result_1b), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1b), singlenode_b_eue, nstderr_tol)

        # Three-region system
        result_3 = assess(simspec, Minimal(), threenode)
        @test withinrange(LOLE(result_3), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3), threenode_eue, nstderr_tol)

    end

    @testset "Temporal Result" begin

        # Single-region system A
        result_1ab = assess(simspec, Temporal(), singlenode_a)
        @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)

        @test all(withinrange.(LOLP.(result_1ab, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1ab, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))

        # Single-region system B
        result_1bb = assess(simspec, Temporal(), singlenode_b)
        @test withinrange(LOLE(result_1bb), singlenode_b_lole, nstderr_tol)
        @test withinrange(EUE(result_1bb), singlenode_b_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1bb, timestampcol_b),
                               singlenode_b_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1bb, timestampcol_b),
                               singlenode_b_eues, nstderr_tol))

        # Three-region system
        result_3mb = assess(simspec, Temporal(), threenode)
        @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3mb, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3mb, timestampcol_3),
                               threenode_eues, nstderr_tol))

    end

    @testset "SpatioTemporal Result" begin

        # Single-region system A
        result_1ab = assess(simspec, SpatioTemporal(), singlenode_a)
        @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(result_1ab, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1ab, "Region"), singlenode_a_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1ab, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1ab, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1ab, "Region", timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1ab, "Region", timestampcol_a),
                               singlenode_a_eues, nstderr_tol))

        # Single-region system B
        result_1bb = assess(simspec, SpatioTemporal(), singlenode_b)
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

        # Three-region system
        result_3mb = assess(simspec, SpatioTemporal(), threenode)
        @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3mb, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3mb, timestampcol_3),
                               threenode_eues, nstderr_tol))

        @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,1)), 0.1, nstderr_tol)
        @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,2)), 0.1, nstderr_tol)

    end

    @testset "Network Result" begin

        # Single-region system A
        result_1ab = assess(simspec, Network(), singlenode_a)
        @test withinrange(LOLE(result_1ab), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1ab), singlenode_a_eue, nstderr_tol)
        @test withinrange(LOLE(result_1ab, "Region"), singlenode_a_lole, nstderr_tol)
        @test withinrange(EUE(result_1ab, "Region"), singlenode_a_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_1ab, timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1ab, timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test all(withinrange.(LOLP.(result_1ab, "Region", timestampcol_a),
                               singlenode_a_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_1ab, "Region", timestampcol_a),
                               singlenode_a_eues, nstderr_tol))
        @test length(result_1ab.flows) == 0
        @test length(result_1ab.utilizations) == 0

        # Single-region system B
        result_1bb = assess(simspec, Network(), singlenode_b)
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

        # Three-region system
        result_3mb = assess(simspec, Network(), threenode)
        @test withinrange(LOLE(result_3mb), threenode_lole, nstderr_tol)
        @test withinrange(EUE(result_3mb), threenode_eue, nstderr_tol)
        @test all(withinrange.(LOLP.(result_3mb, timestampcol_3),
                               threenode_lolps, nstderr_tol))
        @test all(withinrange.(EUE.(result_3mb, timestampcol_3),
                               threenode_eues, nstderr_tol))

        @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,1)), 0.1, nstderr_tol)
        @test withinrange(LOLP(result_3mb, "Region C", DateTime(2018,10,30,2)), 0.1, nstderr_tol)

    end

    # SpatioTemporal
    println("SpatioTemporal")
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
    println("Network ExpectedInterfaceFlows:")
    threenode_interfaces = tuple.(threenode.interfaces.regions_from,
                                  threenode.interfaces.regions_to)
    interfacenamesrow = reshape([(threenode.regions.names[from], threenode.regions.names[to])
                             for (from, to) in threenode_interfaces],
                            1, :)
    interfacesrow = reshape(threenode_interfaces, 1, :)
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
