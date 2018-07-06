@testset "NonSequentialNetworkFlow" begin

    # TODO: Decide on how to programmatically test MC estimates vs ground truth
    @test_broken false

    println("Single-node system A")
    println("Theoretical:")
    println("LOLP = 0.06")
    println("EUE = _")

    println("Minimal:")
    result_1a_minimal = assess(NonSequentialNetworkFlow(100_000),
                               MinimalResult(), singlenode_a)
    println(LOLP(result_1a_minimal))
    println(EUE(result_1a_minimal))

    println("Network:")
    result_1a_network = assess(NonSequentialNetworkFlow(100_000),
                               NetworkResult(failuresonly=true), singlenode_a)
    println(LOLP(result_1a_network))
    println(EUE(result_1a_network))
    println()


    println("Single-node system B")
    println("Theoretical:")
    println("LOLP = 1e-5")
    println("EUE = _")

    println("Minimal:")
    result_1b_minimal = assess(NonSequentialNetworkFlow(1_000_000),
                               MinimalResult(), singlenode_b)
    println(LOLP(result_1b_minimal))
    println(EUE(result_1b_minimal))

    println("Network:")
    result_1b_network = assess(NonSequentialNetworkFlow(1_000_000),
                               NetworkResult(failuresonly=true), singlenode_b)
    println(LOLP(result_1b_network))
    println(EUE(result_1b_network))
    println()


    println("Three-node system A")
    #TODO: Network case is tractable, calculate true values
    println("Theoretical:")
    println("LOLP = _")
    println("EUE = _")

    println("Minimal:")
    result_3a_minimal = assess(NonSequentialNetworkFlow(100_000),
                               MinimalResult(), threenode_a)
    println(LOLP(result_3a_minimal))
    println(EUE(result_3a_minimal))

    println("Network:")
    result_3a_network = assess(NonSequentialNetworkFlow(100_000),
                               NetworkResult(failuresonly=true), threenode_a)
    println(LOLP(result_3a_network))
    println(EUE(result_3a_network))
    println()


    println("Three-node system B")
    #TODO: Network case is tractable, calculate true values
    println("Theoretical:")
    println("LOLP = _")
    println("EUE = _")

    println("Minimal:")
    result_3b_minimal = assess(NonSequentialNetworkFlow(100_000),
                               MinimalResult(), threenode_b)
    println(LOLP(result_3b_minimal))
    println(EUE(result_3b_minimal))

    println("Network:")
    result_3b_network = assess(NonSequentialNetworkFlow(100_000),
                               NetworkResult(failuresonly=true), threenode_b)
    println(LOLP(result_3b_network))
    println(EUE(result_3b_network))
    println()


    println("Multi-period three-node system")
    #TODO: Network case is tractable, calculate true values
    println("Theoretical:")
    println("LOLE = _")
    println("EUE = _")

    println("Minimal, Backcast:")
    result_3mb_minimal = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                                MinimalResult(), threenode_multiperiod)
    println(LOLE(result_3mb_minimal))
    println(EUE(result_3mb_minimal))

    println("Minimal, REPRA(1,1):")
    result_3mr_minimal = assess(REPRA(1,1), NonSequentialNetworkFlow(100_000),
                                MinimalResult(), threenode_multiperiod)
    println(LOLE(result_3mr_minimal))
    println(EUE(result_3mr_minimal))

    println("Network, Backcast:")
    result_3mb_network = assess(Backcast(), NonSequentialNetworkFlow(100_000),
                                NetworkResult(failuresonly=true),
                                threenode_multiperiod)
    println(LOLE(result_3mb_network))
    println(EUE(result_3mb_network))

    println("Network, REPRA(1,1): ")
    result_3mr_network = assess(REPRA(1,1), NonSequentialNetworkFlow(100_000),
                                NetworkResult(failuresonly=true),
                                threenode_multiperiod)
    println(LOLE(result_3mr_network))
    println(EUE(result_3mr_network))
    println()

end
