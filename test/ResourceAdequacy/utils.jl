@testset "Utils" begin
    @testset "Convolution" begin

        # x = rand(10000)
        # a = DiscreteNonParametric(cumsum(rand(1:100, 10000)), x ./ sum(x))

        # y = rand(10000)
        # b = DiscreteNonParametric(cumsum(rand(1:100, 10000)), y ./ sum(y))

    end

    @testset "Distribution Assessment" begin
        distr = DiscreteNonParametric([-2, -1, 0, 1, 2], fill(0.2, 5))
        lolp, eul = assess(distr)
        es = ResourceAdequacy.surplus(distr)

        @test isapprox(lolp, 0.4)
        @test isapprox(eul, 0.6)
        @test isapprox(es, 0.6)

        distr = DiscreteNonParametric([1, 2, 3, 4, 5], fill(0.2, 5))
        lolp, eul = assess(distr)
        es = ResourceAdequacy.surplus(distr)

        @test isapprox(lolp, 0.0)
        @test isapprox(eul, 0.0)
        @test isapprox(es, 3)
    end
end
