@testset "Utils" begin

    @testset "Convolution" begin

        Base.isapprox(x::DiscreteNonParametric, y::DiscreteNonParametric) =
            isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))
        @test ResourceAdequacy.add_dists(DiscreteNonParametric([0, 1], [0.7, 0.3]),
                            DiscreteNonParametric([0, 1], [0.7, 0.3])) ≈
                                DiscreteNonParametric([0,1,2], [.49, .42, .09])

        @test ResourceAdequacy.add_dists(DiscreteNonParametric([0,2], [.9, .1]),
                            DiscreteNonParametric([0,2,3], [.8, .1, .1])) ≈
                                DiscreteNonParametric([0,2,3,4,5], [.72, .17, .09, .01, .01])

        # x = rand(10000)
        # a = DiscreteNonParametric(cumsum(rand(1:100, 10000)), x ./ sum(x))

        # y = rand(10000)
        # b = DiscreteNonParametric(cumsum(rand(1:100, 10000)), y ./ sum(y))

        # @profile ResourceAdequacy.add_dists(a, b)
        # Profile.print(maxdepth=10)

    end

end
