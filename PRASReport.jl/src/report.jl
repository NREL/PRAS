# function run_reports(sim::Simulation; kwargs...)
#     return assess(sim; kwargs...)
# end

"""
    create_html_report(conn::DuckDB.DuckDBConnection; 
                          output_path::String="report.html", 
                          title::String="PRAS Report")
"""
function create_html_report(sf::ShortfallResult,
                            flow::FlowResult;
                            report_name::String="report",
                            threshold::Int=0)
    
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
    
    write(report_name * ".html", report_html)

    return

end                          