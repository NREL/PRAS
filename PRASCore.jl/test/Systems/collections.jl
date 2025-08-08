@testset verbose = true "Collections" begin

    @testset "Regions" begin

        Regions{10,MW}(["Region A", "Region B"], rand(1:10, 2, 10))

        @test_throws AssertionError Regions{10,MW}(
            ["Region A", "Region B"], rand(1:10, 2, 5))

        @test_throws AssertionError Regions{10,MW}(
            ["Region A", "Region B"], rand(1:10, 3, 10))

        @test_throws AssertionError Regions{10,MW}(
            ["Region A", "Region B"], -rand(1:10, 2, 10))

    end

    @testset "Interfaces" begin

        Interfaces{10,MW}(
            [1,1,2], [2,3,3], rand(1:15, 3, 10), rand(1:15, 3, 10))

        @test_throws AssertionError Interfaces{10,MW}(
            [1,1,2], [2,3], rand(1:15, 3, 10), rand(1:15, 3, 10))

        @test_throws AssertionError Interfaces{10,MW}(
            [1,1,2], [2,3,3], rand(1:15, 2, 10), rand(1:15, 2, 10))

        @test_throws AssertionError Interfaces{10,MW}(
            [1,1,2], [2,3,3], rand(1:15, 3, 11), rand(1:15, 3, 11))

        @test_throws AssertionError Interfaces{10,MW}(
            [1,1,2], [2,3,3], rand(1:15, 3, 10), -rand(1:15, 3, 10))

    end

end
