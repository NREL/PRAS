@testset "SystemModel" begin
    generators = Generators{10, 1, Hour, MW}(
        ["Gen A", "Gen B"],
        ["CC", "CT"],
        rand(1:10, 2, 10),
        fill(0.1, 2, 10),
        fill(0.1, 2, 10),
    )

    storages = Storages{10, 1, Hour, MW, MWh}(
        ["S1", "S2"],
        ["Battery", "Pumped Hydro"],
        rand(1:10, 2, 10),
        rand(1:10, 2, 10),
        rand(1:10, 2, 10),
        fill(0.9, 2, 10),
        fill(1.0, 2, 10),
        fill(0.99, 2, 10),
        fill(0.1, 2, 10),
        fill(0.5, 2, 10),
    )

    generatorstorages = GeneratorStorages{10, 1, Hour, MW, MWh}(
        ["GS1"],
        ["CSP"],
        rand(1:10, 1, 10),
        rand(1:10, 1, 10),
        rand(1:10, 1, 10),
        fill(0.9, 1, 10),
        fill(1.0, 1, 10),
        fill(0.99, 1, 10),
        rand(1:10, 1, 10),
        rand(1:10, 1, 10),
        rand(1:10, 1, 10),
        fill(0.1, 1, 10),
        fill(0.5, 1, 10),
    )

    timestamps = DateTime(2020, 1, 1, 0):Hour(1):DateTime(2020, 1, 1, 9)

    # Single-region constructor
    SystemModel(generators, storages, generatorstorages, timestamps, rand(1:20, 10))

    regions = Regions{10, MW}(["Region A", "Region B"], rand(1:20, 2, 10))

    interfaces = Interfaces{10, MW}([1], [2], fill(100, 1, 10), fill(100, 1, 10))

    lines = Lines{10, 1, Hour, MW}(
        ["Line 1", "Line 2"],
        ["Line", "Line"],
        fill(10, 2, 10),
        fill(10, 2, 10),
        fill(0.0, 2, 10),
        fill(1.0, 2, 10),
    )

    gen_regions = [1:1, 2:2]
    stor_regions = [1:0, 1:2]
    genstor_regions = [1:1, 2:1]
    line_interfaces = [1:2]

    # Multi-region constructor
    SystemModel(
        regions,
        interfaces,
        generators,
        gen_regions,
        storages,
        stor_regions,
        generatorstorages,
        genstor_regions,
        lines,
        line_interfaces,
        timestamps,
    )
end
