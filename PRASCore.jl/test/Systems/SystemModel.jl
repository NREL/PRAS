@testset "SystemModel" begin

    generators = Generators{10,1,Hour,MW}(
        ["Gen A", "Gen B"], ["CC", "CT"],
        rand(1:10, 2, 10), fill(0.1, 2, 10), fill(0.1, 2, 10))

    storages = Storages{10,1,Hour,MW,MWh}(
        ["S1", "S2"], ["Battery", "Pumped Hydro"],
        rand(1:10, 2, 10), rand(1:10, 2, 10), rand(1:10, 2, 10),
        fill(0.9, 2, 10), fill(1.0, 2, 10), fill(0.99, 2, 10),
        fill(0.1, 2, 10), fill(0.5, 2, 10))

    generatorstorages = GeneratorStorages{10,1,Hour,MW,MWh}(
        ["GS1"], ["CSP"],
        rand(1:10, 1, 10), rand(1:10, 1, 10), rand(1:10, 1, 10),
        fill(0.9, 1, 10), fill(1.0, 1, 10), fill(0.99, 1, 10),
        rand(1:10, 1, 10), rand(1:10, 1, 10), rand(1:10, 1, 10),
        fill(0.1, 1, 10), fill(0.5, 1, 10))

    tz = tz"UTC"
    timestamps = ZonedDateTime(2020, 1, 1, 0, tz):Hour(1):ZonedDateTime(2020,1,1,9, tz)
    attrs = Dict("type" => "Single-Region System")

    # Single-region constructor
    single_reg_sys = SystemModel(
        generators, storages, generatorstorages, timestamps, rand(1:20, 10), attrs)
    @test single_reg_sys isa SystemModel

    io = IOBuffer()
    show(io, "text/plain", single_reg_sys)
    text = String(take!(io))
    @test occursin("PRAS system with 1 regions,", text)
    @test occursin("Region names:", text)
    @test occursin("Assets:", text)
    @test occursin("Time series:", text)
    @test occursin("Attributes:", text)
    
    regions = Regions{10,MW}(
        ["Region A", "Region B"], rand(1:20, 2, 10))

    interfaces = Interfaces{10,MW}(
        [1], [2], fill(100, 1, 10), fill(100, 1, 10))

    lines = Lines{10,1,Hour,MW}(
        ["Line 1", "Line 2"], ["Line", "Line"],
        fill(10, 2, 10), fill(10, 2, 10), fill(0., 2, 10), fill(1.0, 2, 10))

    gen_regions = [1:1, 2:2]
    stor_regions = [1:0, 1:2]
    genstor_regions = [1:1, 2:1]
    line_interfaces = [1:2]

    # Multi-region constructor
    multi_region_sys_wo_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps)
    @test multi_region_sys_wo_attrs isa SystemModel

    attrs = Dict("type" => "Multi-Region System")
    multi_region_sys_with_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps, attrs)
    @test multi_region_sys_with_attrs isa SystemModel
    
    io = IOBuffer()
    show(io, "text/plain", multi_region_sys_with_attrs)
    text = String(take!(io))
    @test occursin("PRAS system with 2 regions, and 1 interfaces between these regions.", text)
    @test occursin("Region names:", text)
    @test occursin("Generators: 2", text)
    @test occursin("Storages: 2", text)
    @test occursin("GeneratorStorages: 1", text)
    @test occursin("Lines: 2", text)
    @test occursin("Resolution: 1", text)
    @test occursin("Resolution: 1", text)
    @test occursin("Time zone: UTC", text)
    @test occursin("type: Multi-Region System", text)

    attrs = Dict("type" => "Multi-Region System", "year" => 2025)
    @test_throws MethodError multi_region_sys_with_attrs = SystemModel(
        regions, interfaces,
        generators, gen_regions, storages, stor_regions,
        generatorstorages, genstor_regions,
        lines, line_interfaces,
        timestamps, attrs)
    
end

