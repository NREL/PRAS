using Revise
using PRAS
using PRASReport

rts_sys = rts_gmlc()
rts_sys.regions.load .+= 375

sf, flow, events = assess(
    rts_sys,
    SequentialMonteCarlo(samples=100),
    Shortfall(),
    Flow(),
    ShortfallEvents(),
)

report_path = joinpath(pwd(), "pras_report_results")

create_pras_report(
    sf,
    flow,
    events;
    report_name="example_rts_report",
    report_path=report_path,
    title="RTS-GMLC (load modified) RA Report",
)
