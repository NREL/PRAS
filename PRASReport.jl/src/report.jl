"""
    create_html_report(sf::ShortfallResult, flow::FlowResult;
                        report_name::String,
                        threshold::Int,
                        title::String)

Create a HTML report from PRAS simulation results from 
ShortfallResult and FlowResult objects.

# Arguments
- `sf::ShortfallResult`: Simulation ShortfallResult 
- `flow::FlowResult`: Simulation FlowResult
- `report_name::String`: Base name for the generated HTML file (default: "report")
- `threshold::Int`: Event threshold for filtering events (default: 0)
- `title::String`: Title to display in the report header (default: "Resource Adequacy Report")
"""
function create_html_report(sf::ShortfallResult,
                            flow::FlowResult;
                            report_name::String="report",
                            threshold::Int=0,
                            title::String="Resource Adequacy Report")

    base64_db = _get_base64_db((sf,flow);threshold=threshold)

    return  _html_report(base64_db; 
                            report_name=report_name,
                            title=title)
end
"""
    create_html_report(system::SystemModel;
                        samples,seed,
                        report_name::String="report",
                        threshold::Int=0,
                        title::String="Resource Adequacy Report")

Create a HTML report when a PRAS system and simulation parameters are provided.

# Arguments
- `system::SystemModel`: PRAS system
- `samples`: Number of Monte Carlo samples (default: 1000)
- `seed`: Random seed for MC simulation (default: 1)
"""
function create_html_report(system::SystemModel;
                            samples=1000,seed=1,
                            report_name::String="report",
                            threshold::Int=0,
                            title::String="Resource Adequacy Report")

    base64_db = _get_base64_db((system,);threshold=threshold,
                                samples=samples,seed=seed)

    return  _html_report(base64_db; 
                            report_name=report_name,
                            title=title)
end

"""
    create_html_report(system_path::SystemModel;
                        samples,seed,
                        report_name::String="report",
                        threshold::Int=0,
                        title::String="Resource Adequacy Report")

Create a HTML report when a path to the .pras system and simulation
parameters are provided.

# Arguments
- `system_path::String`: Path to the .pras file
"""
function create_html_report(system_path::String;
                            samples=1000,seed=1,
                            report_name::String="report",
                            threshold::Int=0,
                            title::String="Resource Adequacy Report")

    base64_db = _get_base64_db((system_path,);threshold=threshold,
                                samples=samples,seed=seed)
    
    return  _html_report(base64_db; 
                            report_name=report_name,
                            title=title)
end

"""
Internal function to get events database for different types of inputs.
"""    
function _get_base64_db(get_db_args; 
                        samples=1000,seed=1,
                        threshold::Int=0, 
                        report_name::String="report",
                        title::String="Resource Adequacy Report")

    tempdb_path = tempname() * ".db"
    dbfile = DuckDB.open(tempdb_path)
    conn = DuckDB.connect(dbfile)    
    conn = get_db(get_db_args...; conn, threshold=threshold,
                    samples=samples, seed=seed)

    DuckDB.DBInterface.close!(conn)
    DuckDB.close_database(dbfile)

    # Convert temp db to base64 string and delete temp file
    base64_db = base64encode(read(tempdb_path))
    rm(tempdb_path; force=true)
    
    return base64_db

end

"""
    _html_report(base64_db::String;
                    report_name::String,
                    title::String")

Internal function to create a HTML report from PRAS simulation results stored in a 
base64-encoded DuckDB database string.

# Arguments
- `base64_db::String`: Base64-encoded DuckDB database string
- `report_name::String`: Base name for the generated HTML file (default: "report")
- `title::String`: Title to display in the report header (default: "Resource Adequacy Report")
"""
function _html_report(base64_db::String;
                        report_name::String="report",
                        title::String="Resource Adequacy Report")
    
    report_html = read(joinpath(@__DIR__, "report_template.html"), String)
    report_html = replace(report_html, 
                            "        // Placeholder for base64 database - this will be replaced by Julia" => "")
    report_html = replace(report_html, 
                            "const BASE64_DB = \"{{BASE64_DB_PLACEHOLDER}}\"" => "const BASE64_DB = \"$(base64_db)\"")
    report_html = replace(report_html, 
                            "{{REPORT_TITLE_PLACEHOLDER}}" => title)
    
    report_path = joinpath(pwd(), report_name * ".html")
    println("Writing report to: ", report_path)
    write(report_name * ".html", report_html)

    return

end                          
