"""
    create_pras_report(sf::ShortfallResult, flow::FlowResult;
                        report_name::String,
                        report_path::String,
                        title::String)

Create a HTML report from PRAS simulation results from 
ShortfallResult and FlowResult objects.

# Arguments
- `sf::ShortfallResult`: Simulation ShortfallResult 
- `flow::FlowResult`: Simulation FlowResult
- `events::ShortfallEventsResult`:
- `report_name::String`: Base name for the generated HTML file (default: "report")
- `report_path::String`: Directory path where the HTML report and DuckDB database will be saved (default: pwd())
- `title::String`: Title to display in the report header (default: "Resource Adequacy Report")
"""
function create_pras_report(sf::ShortfallResult,
                            flow::FlowResult,
                            events::ShortfallEventsResult;
                            report_name::String="report",
                            report_path::String=pwd(),
                            title::String="Resource Adequacy Report")

    return _create_report(
        (sf, flow, events);
        report_name,
        report_path,
        title,
    )
end

function create_pras_report(sf::ShortfallResult,
                            flow::FlowResult,
                            utilization::UtilizationResult,
                            events::ShortfallEventsResult;
                            report_name::String="report",
                            report_path::String=pwd(),
                            title::String="Resource Adequacy Report")

    return _create_report(
        (sf, flow, utilization, events);
        report_name,
        report_path,
        title,
    )
end

"""
    create_pras_report(system::SystemModel;
                        samples,seed,
                        report_name::String="report",
                        report_path::String=pwd(),
                        title::String="Resource Adequacy Report")

Create a HTML report when a PRAS system and simulation parameters are provided.

# Arguments
- `system::SystemModel`: PRAS system
- `samples`: Number of Monte Carlo samples (default: 1000)
- `seed`: Random seed for MC simulation (default: 1)
"""
function create_pras_report(system::SystemModel;
                            samples=1000,seed=1,
                            report_name::String="report",
                            report_path::String=pwd(),
                            title::String="Resource Adequacy Report")

    return _create_report(
        (system,);
        samples,
        seed,
        report_name,
        report_path,
        title,
    )
end

"""
    create_pras_report(system_path::String;
                        samples,seed,
                        report_name::String="report",
                        report_path::String=pwd(),
                        title::String="Resource Adequacy Report")

Create a HTML report when a path to the .pras system and simulation
parameters are provided.

# Arguments
- `system_path::String`: Path to the .pras file
"""
function create_pras_report(system_path::String;
                            samples=1000,seed=1,
                            report_name::String="report",
                            report_path::String=pwd(),
                            title::String="Resource Adequacy Report")

    return _create_report(
        (system_path,);
        samples,
        seed,
        report_name,
        report_path,
        title,
    )
end

"""
Internal function to create the matched report database and HTML outputs.
"""
function _create_report(
    get_db_args;
    samples=1000,
    seed=1,
    report_name::String,
    report_path::String,
    title,
)
    mkpath(report_path)

    full_report_path = joinpath(report_path, report_name * ".html")
    database_path = joinpath(report_path, report_name * ".duckdb")

    rm(database_path; force=true)

    base64_db = _write_report_db(
        get_db_args,
        database_path;
        samples,
        seed,
    )

    return _html_report(
        base64_db;
        full_report_path,
        title,
    )
end

"""
Internal function to write a report database and return its base64 representation.
"""
function _write_report_db(
    get_db_args,
    database_path::String;
    samples=1000,
    seed=1,
)
    println("Writing database to: ", database_path)
    dbfile = DuckDB.open(database_path)
    conn = DuckDB.connect(dbfile)

    try
        get_db(get_db_args...; conn, samples, seed)
    finally
        DuckDB.DBInterface.close!(conn)
        DuckDB.close_database(dbfile)
    end

    return base64encode(read(database_path))

end

"""
Internal function to create a HTML report from PRAS simulation results stored in a 
base64-encoded DuckDB database string.
"""
function _html_report(
    base64_db::String;
    full_report_path::String,
    title)

    queries_js = read(joinpath(@__DIR__, "report_queries.js"), String)
    plots_js = read(joinpath(@__DIR__, "report_plots.js"), String)
    styles_css = read(joinpath(@__DIR__, "report_style.css"), String)

    report_html = read(joinpath(@__DIR__, "report_template.html"), String)

    report_html = replace(report_html,
    "        // Placeholder for base64 database - this will be replaced by Julia" => "")

    report_html = replace(report_html,
    "const BASE64_DB = \"{{BASE64_DB_PLACEHOLDER}}\"" =>
    "const BASE64_DB = \"$(base64_db)\"")

    report_html = replace(report_html,
    "{{REPORT_TITLE_PLACEHOLDER}}" => title)

    report_html = replace(report_html,
    "{{REPORT_STYLES_CSS_PLACEHOLDER}}" => styles_css)

    report_html = replace(report_html,
    "{{REPORT_QUERIES_JS_PLACEHOLDER}}" => "\nconsole.log('QUERIES JS INJECTED');\n" * queries_js)

    report_html = replace(report_html,
    "{{REPORT_PLOTS_JS_PLACEHOLDER}}" => plots_js)

    @assert !contains(report_html, "{{REPORT_STYLES_CSS_PLACEHOLDER}}")
    @assert !contains(report_html, "{{REPORT_QUERIES_JS_PLACEHOLDER}}")
    @assert !contains(report_html, "{{REPORT_PLOTS_JS_PLACEHOLDER}}")

    println("Writing report to: ", full_report_path)
    write(full_report_path, report_html)

    return
end                    
