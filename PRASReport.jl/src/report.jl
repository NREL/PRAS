# function run_reports(sim::Simulation; kwargs...)
#     return assess(sim; kwargs...)
# end

"""
    get_db(sf::ShortfallResult{N,L,T,E},
                flow::FlowResult{N,L,T,P}=nothing;
                conn::DuckDB.Connection=nothing,
                threshold=0

Extract events from PRAS results and write them to database.
Returns the event IDs for further processing.
"""
function get_db(sf::ShortfallResult{N,L,T,E},
                flow::Union{FlowResult{N,L,T,P},Nothing}=nothing;
                conn::Union{DuckDB.Connection,Nothing}=nothing,
                threshold=0) where {N,L,T,P,E}
    
    if isnothing(conn)
        timenow = Dates.format(now(tz"UTC"), @dateformat_str"yyyy-mm-dd_HHMMSSZZZ")
        dbfile = DuckDB.open(joinpath(@__DIR__, "$(timenow).duckdb"))
        conn = DuckDB.DBInterface.connect(dbfile)    
    end

    # Load in DB schema
    schema_file = joinpath(dirname(@__FILE__), "event_db_schema.sql")
    schema_sql = read(schema_file, String)

    # Split schema into individual statements and execute each one
    # Remove SQL comments (lines starting with --)
    schema_sql = join(filter(line -> !startswith(strip(line), "--"), split(schema_sql, '\n')), '\n')
    statements = split(schema_sql, ';')
    for stmt in statements
        stmt_clean = strip(stmt)
        if !isempty(stmt_clean) && !startswith(stmt_clean, "--")
            try
                DuckDB.DBInterface.execute(conn, stmt_clean)
            catch e
                println("Error executing statement: $stmt_clean")
                rethrow(e)
            end
        end
    end

    # Write system & simulation parameters to database
    write_db!(sf, flow, conn)
    
    # Write region names to database
    write_db!(sf.regions.names, conn)

    # Extract events from shortfall results
    events = get_events(sf,threshold)
    
    # Write events to database (events, system metrics, regional metrics)
    foreach(event -> write_db!(event,conn), events)
    
    # Write time-series shortfall data for each event
    sf_timeseries_allevents = Shortfall_timeseries.(events, sf)
    foreach(sf_ts -> write_db!(sf_ts,conn), sf_timeseries_allevents)
    
    # Write flow data if provided
    if !isnothing(flow)
        write_db!(flow.interfaces, conn) 
        flow_timeseries_allevents = Flow_timeseries.(events, flow)
        foreach(flow_ts -> write_db!(flow_ts,conn), flow_timeseries_allevents)
    end

    DuckDB.DBInterface.close!(conn)
    DuckDB.close_database(dbfile)

    return

end