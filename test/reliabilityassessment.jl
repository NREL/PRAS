println("Single-node system A")
x = LOLP(assess(Copperplate(), singlenode_a))
@test val(x) ≈ 0.06
@test stderr(x) ≈ 0.
println("Copper Plate: ", x)
println("Network Flow: ", LOLP(assess(NetworkFlow(100_000), singlenode_a)))
println()


println("Single-node system B")
x = LOLP(assess(Copperplate(), singlenode_b))
@test val(x) ≈ 1e-5
@test stderr(x) ≈ 0.
println("Copper Plate: ", x)
println("Network Flow: ", LOLP(assess(NetworkFlow(1_000_000), singlenode_b)))
println()


println("Three-node system A")
x = LOLP(assess(Copperplate(), threenode_a))
@test val(x) ≈ 0.1408
@test stderr(x) ≈ 0.
println("Copper Plate: ", x)
#TODO: Network case is tractable, calculate true LOLP
result = assess(NetworkFlow(100_000, true), threenode_a)
println("Network Flow: ", LOLP(result), " (exact is _)")
println()


println("Three-node system B")
println("Copper Plate: ", LOLP(assess(Copperplate(), threenode_b)))
#TODO: Network case is tractable, calculate analytical LOLP
println("Network Flow: ",
        LOLP(assess(NetworkFlow(100_000), threenode_b)),
        " (exact is _)")
println()


println("Multi-period three-node system")
println("Copper Plate, Backcast: ",
        LOLE(assess(Backcast(), Copperplate(), threenode_multiperiod)))
println("Copper Plate, REPRA(1,1): ",
        LOLE(assess(REPRA(1,1), Copperplate(), threenode_multiperiod)))
#TODO: Network case is tractable, calculate analytical LOLE
println("Network Flow, Backcast: ",
        LOLE(assess(Backcast(), NetworkFlow(100_000), threenode_multiperiod)))
println("Network Flow, REPRA(1,1): ",
        LOLE(assess(REPRA(1,1), NetworkFlow(100_000), threenode_multiperiod)))
println()


if false # Check convolution
    Base.isapprox(x::Generic, y::Generic) =
        isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))
    @test ResourceAdequacy.add_dists(Generic([0, 1], [0.7, 0.3]),
                          Generic([0, 1], [0.7, 0.3])) ≈
                              Generic([0,1,2], [.49, .42, .09])

    @test ResourceAdequacy.add_dists(Generic([0,2], [.9, .1]),
                          Generic([0,2,3], [.8, .1, .1])) ≈
                              Generic([0,2,3,4,5], [.72, .17, .09, .01, .01])

    x = rand(10000)
    a = Generic(cumsum(rand(1:100, 10000)), x ./ sum(x))

    y = rand(10000)
    b = Generic(cumsum(rand(1:100, 10000)), y ./ sum(y))

    @profile ResourceAdequacy.add_dists(a, b)
    Profile.print(maxdepth=10)
end
