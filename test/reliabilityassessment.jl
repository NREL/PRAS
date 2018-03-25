using Distributions

println("Single-node system A")
sys = ResourceAdequacy.SystemDistribution{1,Hour,MWh}(
    [Generic([2.,3,4], [.3, .4, .3])],
    zeros(1, 10),
    Tuple{Int,Int}[],
    Generic{Float64, Float64, Vector{Float64}}[],
    [1. 1 1 1 2 2 2 2 3 3]
)
x = lolp(assess(REPRA,sys))
@test val(x) ≈ 0.06
@test stderr(x) ≈ 0.
println("REPRA: ", x)
println("REPRA-T: ", lolp(assess(REPRA_T, sys, 100_000)))
println()

println("Single-node system B")
sys = ResourceAdequacy.SystemDistribution{1,Hour,MWh}(
    Generic([2.,3,4], [.001, .4, .599]),
    zeros(100),
    [ones(59); fill(2., 40); 3]
)
x = lolp(assess(REPRA, sys))
@test val(x) ≈ 1e-5
@test stderr(x) ≈ 0.
println("REPRA: ", x)
println("REPRA-T: ", lolp(assess(REPRA_T, sys, 1_000_000)))
println()

println("Three-node system A")
gen_dists = [Generic([2., 3], [.4, .6]),
             Generic([2., 3], [.4, .6]),
             Generic([2., 3], [.4, .6])]
vg = zeros(3,5)
load = Matrix{Float64}(3,5)
load[:, 1:3] = 2.
load[:, 4:5] = 2.5
line_labels = [(1,2), (2,3), (1,3)]
line_dists = [Generic([0., 1], [.1, .9]),
              Generic([0., 1], [.3, .7]),
              Generic([0., 1], [.3, .7])]

sys_dist = ResourceAdequacy.SystemDistribution{1,Hour,MWh}(
    gen_dists, vg,
    line_labels, line_dists,
    load
)
x = lolp(assess(REPRA, sys_dist))
@test val(x) ≈ 0.1408
@test stderr(x) ≈ 0.
println("REPRA: ", x)
#TODO: Network case is tractable, calculate true LOLP
println("REPRA-T: ",
        lolp(assess(REPRA_T, sys_dist, 100_000)),
        " (exact is _)")
println()

println("Three-node system B")
gen_dists = [Generic([0., 1, 2], [.1, .3, .6]),
            Generic([0., 1, 2], [.1, .3, .6]),
            Generic([0., 1, 2], [.1, .3, .6])]
vg = [.2 .4; 0 0; .1 .15]
line_labels = [(1,2), (2,3), (1,3)]
line_dists = [Generic([0, 1.], [.2, .8]),
              Generic([0, 1.], [.2, .8]),
              Generic([0, 1.], [.2, .8])]
load = [.5 1.5; .5 1.5; .5 1.5]
sys_dist = ResourceAdequacy.SystemDistribution{1,Hour,MWh}(
    gen_dists, vg,
    line_labels, line_dists,
    load
)

#TODO: Network case is tractable, calculate true LOLP
println("REPRA: ", lolp(assess(REPRA, sys_dist)))
println("REPRA-T: ",
        lolp(assess(REPRA_T, sys_dist, 100_000)),
        " (exact is _)")

if false
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
