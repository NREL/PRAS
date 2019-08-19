@testset "Assets" begin

    names = ["A1", "A2", "B1"]
    categories = ["A", "A", "B"]

    vals_int   = rand(1:100, 3, 10)
    vals_float = rand(3, 10)

    @testset "Generators" begin

        Generators{10,1,Hour,MW}(
            names, categories, vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{5,1,Hour,MW}(
            names, categories, vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names[1:2], categories, vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names[1:2], categories[1:2], vals_int, vals_float, vals_float)

        @test_throws AssertionError Generators{10,1,Hour,MW}(
            names, categories, -vals_int, vals_float, vals_float)

    end

    @testset "Storages" begin

        Storages{10,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{5,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names, categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names[1:2], categories[1:2], vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError Storages{10,1,Hour,MW,MWh}(
            names, categories, vals_int, vals_int, vals_int,
            vals_float, vals_float, -vals_float, vals_float, vals_float)

    end

    @testset "GeneratorStorages" begin

        GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{5,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories[1:2],
            vals_int, vals_int, vals_int, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names[1:2], categories[1:2],
            vals_int, vals_int, vals_int, vals_int, vals_int, vals_int,
            vals_float, vals_float, vals_float, vals_float, vals_float)

        @test_throws AssertionError GeneratorStorages{10,1,Hour,MW,MWh}(
            names, categories,
            vals_int, vals_int, vals_int, vals_int, vals_int, vals_int,
            vals_float, vals_float, -vals_float, vals_float, vals_float)

    end

    @testset "Lines" begin

        Lines{10,1,Hour,MW}(
            names, categories, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{5,1,Hour,MW}(
            names, categories, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names[1:2], categories, vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names[1:2], categories[1:2], vals_int, vals_int, vals_float, vals_float)

        @test_throws AssertionError Lines{10,1,Hour,MW}(
            names, categories, -vals_int, vals_int, vals_float, vals_float)

    end

end
