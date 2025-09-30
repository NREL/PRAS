# function run_reports(sim::Simulation; kwargs...)
#     return assess(sim; kwargs...)
# end

"""
    create_html_report(sf::ShortfallResult, flow::FlowResult;
                          report_name::String="report",
                          threshold::Int=0,
                          title::String="Resource Adequacy Report")

Create an HTML report from PRAS simulation results.

# Fields
- `sf::ShortfallResult`: Shortfall simulation results
- `flow::FlowResult`: Flow simulation results
- `report_name::String`: Base name for the generated HTML file (default: "report")
- `threshold::Int`: Event threshold for filtering events (default: 0)
- `title::String`: Title to display in the report header (default: "Resource Adequacy Report")
"""
function create_html_report(sf::ShortfallResult,
                            flow::FlowResult;
                            report_name::String="report",
                            threshold::Int=0,
                            title::String="Resource Adequacy Report")
    
    tempdb_path = tempname() * ".db"
    dbfile = DuckDB.open(tempdb_path)
    conn = DuckDB.connect(dbfile)    

    conn = get_db(sf, flow; conn, threshold=threshold)

    DuckDB.DBInterface.close!(conn)
    DuckDB.close_database(dbfile)

    base64_db = base64encode(read(tempdb_path))
    rm(tempdb_path; force=true)

    report_html = read(joinpath(@__DIR__, "report_template.html"), String)
    report_html = replace(report_html, 
                            "        // Placeholder for base64 database - this will be replaced by Julia" => "")
    report_html = replace(report_html, 
                            "const BASE64_DB = \"{{BASE64_DB_PLACEHOLDER}}\"" => "const BASE64_DB = \"$(base64_db)\"")
    report_html = replace(report_html, 
                            "{{REPORT_TITLE_PLACEHOLDER}}" => title)
    
    write(report_name * ".html", report_html)

    return

end                          