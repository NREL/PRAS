# Single-Node System A
singlenode_a = ResourceAdequacy.SystemDistribution{1,Hour,MW}(
    [Generic([2.,3,4], [.3, .4, .3])],
    zeros(1, 10),
    Tuple{Int,Int}[],
    Generic{Float64, Float64, Vector{Float64}}[],
    [1. 1 1 1 2 2 2 2 3 3]
)

# Single-Node System B
singlenode_b = ResourceAdequacy.SystemDistribution{1,Hour,MW}(
    Generic([2.,3,4], [.001, .4, .599]),
    zeros(100),
    [ones(59); fill(2., 40); 3]
)

# Three-Node System A
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

threenode_a = ResourceAdequacy.SystemDistribution{1,Hour,MW}(
    gen_dists, vg,
    line_labels, line_dists,
    load
)

# Three-Node System B
gen_dists = [Generic([0., 1, 2], [.1, .3, .6]),
             Generic([0., 1, 2], [.1, .3, .6]),
             Generic([0., 1, 2], [.1, .3, .6])]
vg = [.2 .4; 0 0; .1 .15]
line_labels = [(1,2), (2,3), (1,3)]
line_dists = [Generic([0, 1.], [.2, .8]),
              Generic([0, 1.], [.2, .8]),
              Generic([0, 1.], [.2, .8])]
load = [.5 1.5; .5 1.5; .5 1.5]

threenode_b = ResourceAdequacy.SystemDistribution{1,Hour,MW}(
    gen_dists, vg,
    line_labels, line_dists,
    load
)


# Three-Node System Set

threenode_multiperiod = ResourceAdequacy.SystemDistributionSet{1,Hour,4,Hour,MW,Float64}(
    collect(DateTime(2018,10,30,0):Dates.Hour(1):DateTime(2018,10,30,3)),
    gen_dists, [.8 .7 .6 .7; .6 .4 .5 .7; .7 .8 .9 .8],
    line_labels, line_dists,
    [1.4 1.5 1.6 1.7; 1.5 1.6 1.7 1.6; 1.3 1.4 1.5 1.6], 1, 1
)
