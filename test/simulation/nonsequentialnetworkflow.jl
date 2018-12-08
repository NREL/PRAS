@testset "NonSequentialNetworkFlow" begin

    # TODO: Decide on how to programmatically test MC estimates vs ground truth
    @test_broken false

    println("Single-region system A")
    println("Theoretical:")
    println("LOLE = 0.355")
    println("EUE = 1.59")

    println("Minimal:")
    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_a)
    println(LOLE(result_1ab))
    println(EUE(result_1ab))

    println("Spatial:")
    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_a)
    println(LOLE(result_1ab), " ", LOLE(result_1ab, "Region"))
    println(EUE(result_1ab), " ", EUE(result_1ab, "Region"))

    println("Temporal:")
    result_1ab =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_a)
    println(LOLE(result_1ab))
    println(EUE(result_1ab))
    display(hcat(singlenode_a.timestamps,
            LOLP.(result_1ab, singlenode_a.timestamps),
            EUE.(result_1ab, singlenode_a.timestamps)))
    println()


    println("\nSingle-region system B")
    println("Theoretical:")
    println("LOLE = 0.96")
    println("EUE = 7.11")

    println("Minimal:")
    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Minimal(), singlenode_b)
    println(LOLE(result_1bb))
    println(EUE(result_1bb))

    println("Spatial:")
    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Spatial(), singlenode_b)
    println(LOLE(result_1bb), " ", LOLE(result_1bb, "Region"))
    println(EUE(result_1bb), " ", EUE(result_1bb, "Region"))

    println("Temporal:")
    result_1bb =
        assess(Backcast(), NonSequentialNetworkFlow(100_000), Temporal(), singlenode_b)
    println(LOLE(result_1bb))
    println(EUE(result_1bb))
    display(hcat(singlenode_b.timestamps,
            LOLP.(result_1bb, singlenode_b.timestamps),
            EUE.(result_1bb, singlenode_b.timestamps)))
    println()


    println("\nThree-region system")
    println("Theoretical:")
    println("LOLE = 1.3756")
    println("EUE = 12.12885")

    println("Minimal:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Minimal(), threenode)
    println(LOLE(result_3mb))
    println(EUE(result_3mb))

    println("Spatial:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Spatial(), threenode)
    println(LOLE(result_3mb))
    println(EUE(result_3mb))
    display(hcat(threenode.regions,
                 LOLE.(result_3mb, threenode.regions),
                 EUE.(result_3mb, threenode.regions)))

    println("\nTemporal:")
    result_3mb = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                        Temporal(), threenode)
    println(LOLE(result_3mb))
    println(EUE(result_3mb))
    display(hcat(threenode.timestamps,
            LOLP.(result_3mb, threenode.timestamps),
            EUE.(result_3mb, threenode.timestamps)))
    println()

end
