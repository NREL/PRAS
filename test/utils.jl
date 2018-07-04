@testset "Utils" begin

    @testset "Convolution" begin

        Base.isapprox(x::Generic, y::Generic) =
            isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))
        @test ResourceAdequacy.add_dists(Generic([0, 1], [0.7, 0.3]),
                            Generic([0, 1], [0.7, 0.3])) ≈
                                Generic([0,1,2], [.49, .42, .09])

        @test ResourceAdequacy.add_dists(Generic([0,2], [.9, .1]),
                            Generic([0,2,3], [.8, .1, .1])) ≈
                                Generic([0,2,3,4,5], [.72, .17, .09, .01, .01])

        # x = rand(10000)
        # a = Generic(cumsum(rand(1:100, 10000)), x ./ sum(x))

        # y = rand(10000)
        # b = Generic(cumsum(rand(1:100, 10000)), y ./ sum(y))

        # @profile ResourceAdequacy.add_dists(a, b)
        # Profile.print(maxdepth=10)

    end

end
