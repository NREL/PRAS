@testset "Utils" begin

    @testset "Convolution" begin

        Base.isapprox(x::DiscreteNonParametric, y::DiscreteNonParametric) =
            isapprox(support(x), support(y)) && isapprox(probs(x), probs(y))

        # x = rand(10000)
        # a = DiscreteNonParametric(cumsum(rand(1:100, 10000)), x ./ sum(x))

        # y = rand(10000)
        # b = DiscreteNonParametric(cumsum(rand(1:100, 10000)), y ./ sum(y))

    end

end
