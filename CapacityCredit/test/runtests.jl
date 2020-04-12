using ResourceAdequacy
using CapacityCredit
using PRASBase
using Test
using TimeZones

@testset "CapacityCredit" begin

    empty_str = String[]
    empty_int(x) = Matrix{Int}(undef, 0, x)
    empty_float(x) = Matrix{Float64}(undef, 0, x)

    gens = Generators{4,1,Hour,MW}(
        ["Gen1", "Gen2", "Gen3", "VG"],
        ["Gens", "Gens", "Gens", "VG"],
        [fill(10, 3, 4); [5 6 7 8]],
        [fill(0.1, 3, 4); fill(0.0, 1, 4)],
        [fill(0.9, 3, 4); fill(1.0, 1, 4)]
    )

    gens_after = Generators{4,1,Hour,MW}(
        ["Gen1", "Gen2", "Gen3", "Gen4", "VG"],
        ["Gens", "Gens", "Gens", "Gens", "VG"],
        [fill(10, 4, 4); [5 6 7 8]],
        [fill(0.1, 4, 4); fill(0.0, 1, 4)],
        [fill(0.9, 4, 4); fill(1.0, 1, 4)]
    )

    emptystors = Storages{4,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
                      (empty_int(4) for _ in 1:3)...,
                      (empty_float(4) for _ in 1:5)...)

    emptygenstors = GeneratorStorages{4,1,Hour,MW,MWh}(
        (empty_str for _ in 1:2)...,
        (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:3)...,
        (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:2)...)

    load = [25, 28, 27, 24]

    tz = TimeZone("UTC")
    timestamps = ZonedDateTime(2010,1,1,0,tz):Hour(1):ZonedDateTime(2010,1,1,3,tz)

    sys_before = SystemModel(
        gens, emptystors, emptygenstors, timestamps, load)

    sys_after = SystemModel(
        gens_after, emptystors, emptygenstors, timestamps, load)

    @testset "EFC" begin

        cc_l, cc_u = assess(
            EFC{EUE}(10, "Region"),
            Classic(), Minimal(), sys_before, sys_after)

        @test cc_l == 8
        @test cc_u == 9

        cc_l, cc_u = assess(
            EFC{EUE}(10, "Region"),
            Classic(), Minimal(), sys_before, sys_before)

        @test cc_l == 0
        @test cc_u == 1

    end

    @testset "ELCC" begin

        cc_l, cc_u = assess(
            ELCC{EUE}(10, "Region"),
            Classic(), Minimal(), sys_before, sys_after)

        @test cc_l == 7
        @test cc_u == 8

        cc_l, cc_u = assess(
            ELCC{EUE}(10, "Region"),
            Classic(), Minimal(), sys_before, sys_before)

        @test cc_l == 0
        @test cc_u == 1

    end

end
