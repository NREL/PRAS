@testset "SystemModel input to create_pras_report" begin
    sys = deepcopy(system)
    sys.regions.load .+= 375

    report_dir = mktempdir()

    output = @capture_out begin
        create_pras_report(
            sys;
            samples=100,
            seed=1,
            report_name="sysmodel_test",
            report_path=report_dir,
            title="Test Report",
        )
    end

    report_path = joinpath(report_dir, "sysmodel_test.html")

    @test contains(output, "Writing report to:")
    @test isfile(report_path)

    html = read(report_path, String)
    @test contains(html, "Test Report")
    @test contains(html, "Monte Carlo Average Results")
    @test contains(html, "System-Level Results")
    @test contains(html, "Region-Level Results")
    @test contains(html, "Adequacy Events")
    @test contains(html, "System-Level Events")
    @test contains(html, "Region-Level Events")
    @test contains(html, "Flow Time Series by Interface")
    @test contains(html, "interface-flow-timeseries")
    @test contains(html, "Utilization Time Series by Interface")
    @test contains(html, "interface-utilization-timeseries")
    @test contains(html, "const naturalNameCollator = new Intl.Collator")
    @test contains(html, "numeric: true")
    @test contains(html, ".sort(naturalNameCompare)")
    @test contains(html, "regional-shortfall-colorbar")
    @test contains(html, "zmax: showColorbar ? regionalShortfallMax : 1")
    @test contains(html, "showscale: false")
    @test contains(html, "bgcolor: \"rgba(24, 24, 24, 0.85)\"")
end

@testset "Result input to create_pras_report" begin
    sys = deepcopy(system)
    sys.regions.load .+= 375

    sf, flow, utilization, events = assess(
        sys,
        SequentialMonteCarlo(samples=100, seed=1),
        Shortfall(),
        Flow(),
        Utilization(),
        ShortfallEvents(),
    )

    report_dir = mktempdir()

    output = @capture_out begin
        create_pras_report(
            sf,
            flow,
            utilization,
            events;
            report_name="results_test",
            report_path=report_dir,
            title="Results Test Report",
        )
    end

    report_path = joinpath(report_dir, "results_test.html")

    @test contains(output, "Writing report to:")
    @test isfile(report_path)

    html = read(report_path, String)
    @test contains(html, "Results Test Report")
    @test contains(html, "Monte Carlo Average Results")
    @test contains(html, "Regional Mean Shortfall by Month and Hour")
    @test contains(html, "Flow Time Series by Interface")
    @test contains(html, "interface-flow-timeseries")
    @test contains(html, "Utilization Time Series by Interface")
    @test contains(html, "interface-utilization-timeseries")
end
