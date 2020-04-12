@testset "SystemInputStateDistribution" begin

    # Single-node A

    (distr,) = RA.convolvepartitions(singlenode_a.generators, [1], 1)
    @test isapprox(distr, DiscreteNonParametric([5, 15, 25, 35],
                                                [0.001, 0.027, 0.243, 0.729]))

    sysdistr = RA.SystemInputStateDistribution(singlenode_a, 1, copperplate=true)
    @test length(sysdistr.interfaces) == 0
    @test length(sysdistr.regions) == 1
    @test isapprox(sysdistr.regions[1], DiscreteNonParametric(
        [-20, -10, 0, 10], [0.001, 0.027, 0.243, 0.729]))

    # Single-node B

    (distr,) = RA.convolvepartitions(singlenode_b.generators, [1], 4)
    @test isapprox(distr, DiscreteNonParametric(
        [9, 24, 34, 49], [0.01, 0.09, 0.09, 0.81]))

    sysdistr = RA.SystemInputStateDistribution(singlenode_b, 4, copperplate=true)
    @test length(sysdistr.interfaces) == 0
    @test length(sysdistr.regions) == 1
    @test isapprox(sysdistr.regions[1], DiscreteNonParametric(
        [-22, -7, 3, 18], [0.01, 0.09, 0.09, 0.81]))

    # Three-node

    distrs = RA.convolvepartitions(threenode.generators, [1,3,6], 2)
    @test isapprox(distrs[1],
                   DiscreteNonParametric([3, 13], [0.1, 0.9]))
    @test isapprox(distrs[2],
                   DiscreteNonParametric([5, 15, 25], [0.01, 0.18, 0.81]))
    @test isapprox(distrs[3],
                   DiscreteNonParametric([1, 11, 21, 31], [0.01, 0.09, 0.09, 0.81]))

    sysdistr = RA.SystemInputStateDistribution(threenode, 2, copperplate=false)
    @test length(sysdistr.interfaces) == 3
    @test length(sysdistr.regions) == 3
    @test isapprox(sysdistr.regions[1],
                   DiscreteNonParametric([-17, -7], [0.1, 0.9]))
    @test isapprox(sysdistr.regions[2],
                   DiscreteNonParametric([-16, -6, 4], [0.01, 0.18, 0.81]))
    @test isapprox(sysdistr.regions[3],
                   DiscreteNonParametric([-20, -10, 0, 10], [0.01, 0.09, 0.09, 0.81]))

end

