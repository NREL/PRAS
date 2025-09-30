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
        timenow = format(now(tz"UTC"), @dateformat_str"yyyy-mm-dd_HHMMSSZZZ")
        dbfile = DuckDB.open(joinpath(@__DIR__, "$(timenow).duckdb"))
        conn = DuckDB.connect(dbfile)
        internal_conn = true
    else
        internal_conn = false  
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
    write_db!(sf, flow, threshold, conn)
    
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

    if internal_conn
        DuckDB.DBInterface.close!(conn)
        DuckDB.close_database(dbfile)
        return
    else
        return conn
    end

end
# ============================================================================
# Setup Functions
# ============================================================================
"""
    write_db!(::ShortfallResult{N,L,T,E}, ::FlowResult{N,L,T,P}, 
    threshold::Int, conn::DuckDB.Connection)

Write system and simulation parameters to the parameters table.
"""
function write_db!(sf::ShortfallResult{N,L,T,E}, 
                    ::FlowResult{N,L,T,P},
                    threshold::Int64, 
                    conn::DuckDB.Connection) where {N,L,T,P,E}

    try
        
        appender = DuckDB.Appender(conn, "systemsiminfo")
        
        try
            DuckDB.append(appender, N)
            DuckDB.append(appender, L)
            DuckDB.append(appender, unitsymbol_long(T))
            DuckDB.append(appender, unitsymbol(P))
            DuckDB.append(appender, unitsymbol(E))
            DuckDB.append(appender, DateTime(first(sf.timestamps)))
            DuckDB.append(appender, DateTime(last(sf.timestamps)))
            DuckDB.append(appender, string(TimeZone(last(sf.timestamps))))
            DuckDB.append(appender, sf.nsamples)
            DuckDB.append(appender, val(EUE(sf)))
            DuckDB.append(appender, stderror(EUE(sf)))
            DuckDB.append(appender, val(LOLE(sf)))
            DuckDB.append(appender, stderror(LOLE(sf)))
            DuckDB.append(appender, val(NEUE(sf)))
            DuckDB.append(appender, stderror(NEUE(sf)))
            DuckDB.append(appender, threshold)
            DuckDB.end_row(appender)
            DuckDB.flush(appender)
            
        finally
            # Always close the appender
            DuckDB.close(appender)
        end
    catch e 
        rethrow(e)
    end
end

"""
    write_db!(region_names::Vector{String}, conn::DuckDB.Connection)

Write regions to the regions table. Call this once to populate the regions table.
Ignores regions that already exist.
"""
function write_db!(region_names::Vector{String}, conn::DuckDB.Connection)
    for (idx,region_name) in enumerate(region_names)
        try
            DuckDB.execute(conn, "INSERT INTO regions (id, name) VALUES (?,?)", [idx,region_name])
        catch e
            # Region already exists, continue
            if !occursin("UNIQUE constraint", string(e))
                rethrow(e)
            end
        end
    end
end

"""
    write_db!(interfaces::Vector{Pair{String,String}}, conn::DuckDB.Connection)

Write interfaces from region pairs to the interfaces table. 
Each tuple should be (region_from, region_to).
Assumes all regions already exist in the regions table.
Call this once to populate the interfaces table.
"""
function write_db!(interfaces::Vector{Pair{String,String}}, conn::DuckDB.Connection)
    for (idx,interface_pair) in enumerate(interfaces)
        region_from, region_to = interface_pair.first, interface_pair.second
        # Get region IDs
        interface_reg_ids = DuckDB.execute(conn, "SELECT id FROM regions WHERE name IN [?,?]", 
                                            [region_from,region_to]
                                            ) |> columntable
                
        from_id,to_id = [interface_reg_ids.id...]
        
        interface_name = "$region_from->$region_to"
        
        # Insert interface (ignore if already exists due to UNIQUE constraint)
        try
            DuckDB.execute(conn, """
                INSERT INTO interfaces (id, region_from_id, region_to_id, name) 
                VALUES (?, ?, ?, ?)
            """, [idx, from_id, to_id, interface_name])
        catch e
            # Interface already exists, continue
            if !occursin("UNIQUE constraint", string(e))
                rethrow(e)
            end
        end
    end
end

# ============================================================================
# Write Results
# ============================================================================
"""
    write_db!(events::Vector{Event}, conn::DuckDB.Connection)

Write a vector of Event objects to the database using DuckDB Appender API for efficient bulk inserts.
Writes to: events, event_system_shortfall, event_regional_shortfall tables.
"""
function write_db!(events::Vector{Event}, conn::DuckDB.Connection)
    # Write each event individually to avoid memory issues with large datasets
    for event in events
        write_db!(event, conn)
    end
end

"""
    write_db!(event::Event, conn::DuckDB.Connection)

Write a single Event object to the database.
"""
function write_db!(event::Event{N,L,T,E}, conn::DuckDB.Connection) where {N,L,T,E}
    # Get region IDs in the same order as event.regions array
    region_ids = get_region_ids_ordered(event.regions, conn)
    
    # Insert the event record
    event_id = write_event!(event, conn)
    
    # Insert system-level metrics
    write_system_shortfall!(event_id, event, conn)
    
    # Insert regional metrics if they exist
    if !isempty(event.lole) && !isempty(event.eue) && !isempty(event.neue)
        write_regional_shortfall!(event_id, event, region_ids, conn)
    end
    
    return event_id
end

"""
    write_db!(sf_ts::Shortfall_timeseries, conn::DuckDB.Connection)

Write sf_ts time-series data to event_timeseries_shortfall table.
Gets the event_id from the database using the event name for consistency.
"""
function write_db!(sf_ts::Shortfall_timeseries, conn::DuckDB.Connection)
    # Get event_id from database using event name
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", 
                        [sf_ts.name]) |> columntable
    isempty(event_result) &&
        error("Event '$(sf_ts.name)' not found in database. Write the event first.")
    event_id = first(event_result.id)

    # Get region IDs in the same order as sf_ts.regions array
    region_ids = get_region_ids_ordered(sf_ts.regions, conn)
    
    # Use Appender for efficient bulk insert
    appender = DuckDB.Appender(conn, "event_timeseries_shortfall")
    
    try
        # Iterate through timestamps and regions
        for (t_idx, timestamp) in enumerate(sf_ts.timestamps)
            for (r_idx, region_id) in enumerate(region_ids)
                # Append row: event_id, region_id, timestamp_value, lole, eue, neue
                DuckDB.append(appender, event_id)
                DuckDB.append(appender, region_id)
                DuckDB.append(appender, DateTime(timestamp))
                DuckDB.append(appender, sf_ts.lole[t_idx][r_idx])
                DuckDB.append(appender, sf_ts.eue[t_idx][r_idx])
                DuckDB.append(appender, sf_ts.neue[t_idx][r_idx])
                DuckDB.end_row(appender)
            end
        end
        
        # Flush the appender
        DuckDB.flush(appender)
        
    finally
        # Always close the appender
        DuckDB.close(appender)
    end
end

"""
    write_db!(flow_ts::flow_ts, event_id::Integer, conn::DuckDB.Connection)

Write flow_ts time-series data to event_timeseries_flows table.
"""
function write_db!(flow_ts::Flow_timeseries, conn::DuckDB.Connection)

    # Get event_id from database using event name
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", 
                        [flow_ts.name]) |> columntable
    isempty(event_result) &&
        error("Event '$(flow_ts.name)' not found in database. Write the event first.")
    event_id = first(event_result.id)

    # Get interface IDs in the same order as flow_ts.interfaces array
    interface_ids = get_interface_ids_ordered(flow_ts.interfaces, conn)
    
    # Use Appender for efficient bulk insert
    appender = DuckDB.Appender(conn, "event_timeseries_flows")
    
    try
        # Iterate through timestamps and interfaces
        for (t_idx, timestamp) in enumerate(flow_ts.timestamps)
            for (i_idx, interface_id) in enumerate(interface_ids)
                # Append row: event_id, interface_id, timestamp_value, flow
                DuckDB.append(appender, event_id)
                DuckDB.append(appender, interface_id)
                DuckDB.append(appender, DateTime(timestamp))
                DuckDB.append(appender, flow_ts.flow[t_idx][i_idx]) # Extract value from NEUE
                DuckDB.end_row(appender)
            end
        end
        
        # Flush the appender
        DuckDB.flush(appender)
        
    finally
        # Always close the appender
        DuckDB.close(appender)
    end
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    get_region_ids_ordered(region_names::Vector{String}, conn::DuckDB.Connection) -> Vector{Int}

Get region IDs in the same order as the region_names array.
Assumes all regions exist in the database.
"""
function get_region_ids_ordered(region_names::Vector{String}, conn::DuckDB.Connection)
    region_ids = Vector{Int}()
    
    for region_name in region_names
        result = DuckDB.execute(conn, "SELECT id FROM regions WHERE name = ?", [region_name]) |> columntable  
        isempty(result) && error("Region '$region_name' not found in database")
        push!(region_ids, first(result.id))
    end

    return region_ids
end

"""
    get_interface_ids_ordered(interface_names::Vector{String}, conn::DuckDB.Connection) -> Vector{Int}

Get interface IDs in the same order as the interface_names array.
Assumes all interfaces exist in the database.
"""
function get_interface_ids_ordered(interface_names::Vector{Pair{String,String}}, conn::DuckDB.Connection)
    interface_ids = Vector{Int}()
    
    for interface_name in interface_names
        iname_db = "$(interface_name.first)->$(interface_name.second)"
        result = DuckDB.execute(conn, "SELECT id FROM interfaces WHERE name = ?", [iname_db]) |> columntable
        isempty(result) &&
            error("Interface '$interface_name' not found in database")
    
        push!(interface_ids, first(result.id))
    end
    
    return interface_ids
end

"""
    write_event!(event::Event, conn::DuckDB.Connection) -> Int

Write event record to events table and return the event ID.
"""
function write_event!(event::Event, conn::DuckDB.Connection)
    # Extract start and end timestamps
    start_ts = DateTime(first(event.timestamps))
    end_ts = DateTime(last(event.timestamps))
    time_period_count = length(event.timestamps)
    
    # Insert event and get the ID using RETURNING clause
    result = DuckDB.execute(conn, 
                """
                INSERT INTO events (name, start_timestamp, end_timestamp, time_period_count) 
                VALUES (?, ?, ?, ?)
                RETURNING id
                """, 
                [event.name, start_ts, end_ts, time_period_count]) |> columntable
    
    event_id = first(result.id)
    
    return event_id
end

"""
    write_system_shortfall!(event_id::Int, event::Event, conn::DuckDB.Connection)

Write system-level shortfall metrics to event_system_shortfall table.
"""
function write_system_shortfall!(event_id::Int32, event::Event, conn::DuckDB.Connection)
    DuckDB.execute(conn, """
        INSERT INTO event_system_shortfall (event_id, lole, eue, neue) 
        VALUES (?, ?, ?, ?)
    """, [event_id, val(event.system_lole), val(event.system_eue), val(event.system_neue)])
end

"""
    write_regional_shortfall!(event_id::Int, event::Event, region_ids::Vector{Int}, conn::DuckDB.Connection)

Write regional shortfall metrics to event_regional_shortfall table.
"""
function write_regional_shortfall!(event_id::Int32, event::Event, region_ids::Vector{Int}, conn::DuckDB.Connection)
    # Use Appender for efficient bulk insert
    appender = DuckDB.Appender(conn, "event_regional_shortfall")
    
    try
        for (i, region_id) in enumerate(region_ids)
            # Append row: event_id, region_id, lole, eue, neue
            # Note: skipping the 'id' column since it's auto-generated
            DuckDB.append(appender, event_id)
            DuckDB.append(appender, region_id)
            DuckDB.append(appender, val(event.lole[i]))
            DuckDB.append(appender, val(event.eue[i]))
            DuckDB.append(appender, val(event.neue[i]))
            DuckDB.end_row(appender)
        end
        
        # Flush the appender
        DuckDB.flush(appender)
        
    finally
        # Always close the appender
        DuckDB.close(appender)
    end
end


