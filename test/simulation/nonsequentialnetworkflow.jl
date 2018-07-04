@testset "NonSequentialNetworkFlow" begin

    println("Single-node system A")
    println("Network Flow: ", LOLP(assess(NonSequentialNetworkFlow(100_000),
                                        MinimalResult(),
                                        singlenode_a)))
    println()


    println("Single-node system B")
    println("Network Flow: ", LOLP(assess(NonSequentialNetworkFlow(1_000_000),
                                        MinimalResult(),
                                        singlenode_b)))
    println()


    println("Three-node system A")
    #TODO: Network case is tractable, calculate true LOLP
    result = assess(NonSequentialNetworkFlow(100_000),
                    MinimalResult(), threenode_a)
    println("Network Flow: ", LOLP(result), " (exact is _)")
    println()


    println("Three-node system B")
    #TODO: Network case is tractable, calculate analytical LOLP
    println("Network Flow: ",
            LOLP(assess(NonSequentialNetworkFlow(100_000),
                        MinimalResult(),
                        threenode_b)),
            " (exact is _)")
    println()


    println("Multi-period three-node system")
    #TODO: Network case is tractable, calculate analytical LOLE
    println("Network Flow, Backcast: ",
            LOLE(assess(Backcast(), NonSequentialNetworkFlow(100_000), MinimalResult(),
                        threenode_multiperiod)))
    println("Network Flow, REPRA(1,1): ",
            LOLE(assess(REPRA(1,1), NonSequentialNetworkFlow(100_000), MinimalResult(),
                        threenode_multiperiod)))
    println()

end
