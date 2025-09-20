using DuckDB
using Dates

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
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", [sf_ts.name])
    if DuckDB.num_rows(event_result) == 0
        error("Event '$(sf_ts.name)' not found in database. Write the event first.")
    end
    event_id = DuckDB.fetchall(event_result)[1][1]
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
                DuckDB.append(appender, timestamp)
                DuckDB.append(appender, sf_ts.lole[r_idx][t_idx])
                DuckDB.append(appender, sf_ts.eue[r_idx][t_idx])
                DuckDB.append(appender, sf_ts.neue[r_idx][t_idx])
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
    write_db!(flow_ts::Flow_timeseries, conn::DuckDB.Connection)

Write flow_ts time-series data to event_timeseries_flows table.
Gets the event_id from the database using the event name for consistency.
"""
function write_db!(flow_ts::Flow_timeseries, conn::DuckDB.Connection)
    # Get event_id from database using event name
    event_result = DuckDB.execute(conn, "SELECT id FROM events WHERE name = ?", [flow_ts.name])
    if DuckDB.num_rows(event_result) == 0
        error("Event '$(flow_ts.name)' not found in database. Write the event first.")
    end
    event_id = DuckDB.fetchall(event_result)[1][1]
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
                DuckDB.append(appender, timestamp)
                DuckDB.append(appender, val(flow_ts.flow[i_idx][t_idx])) # Extract value from NEUE
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
# Setup Functions
# ============================================================================

"""
    write_regions!(region_names::Vector{String}, conn::DuckDB.Connection)

Write regions to the regions table. Call this once to populate the regions table.
Ignores regions that already exist.
"""
function write_regions!(region_names::Vector{String}, conn::DuckDB.Connection)
    for region_name in region_names
        try
            DuckDB.execute(conn, "INSERT INTO regions (name) VALUES (?)", [region_name])
        catch e
            # Region already exists, continue
            if !occursin("UNIQUE constraint", string(e))
                rethrow(e)
            end
        end
    end
end

"""
    write_interfaces!(interface_specs::Vector{Pair{String,String}}, conn::DuckDB.Connection)

Write interfaces from region pairs to the interfaces table. 
Each tuple should be (region_from, region_to).
Assumes all regions already exist in the regions table.
Call this once to populate the interfaces table.
"""
function write_interfaces!(interface_specs::Vector{Pair{String,String}}, conn::DuckDB.Connection)
    for interface_pair in interface_specs
        region_from, region_to = interface_pair.first, interface_pair.second
        # Get region IDs
        from_result = DuckDB.execute(conn, "SELECT id FROM regions WHERE name = ?", [region_from])
        to_result = DuckDB.execute(conn, "SELECT id FROM regions WHERE name = ?", [region_to])
        
        if DuckDB.num_rows(from_result) == 0
            error("Region '$region_from' not found in database. Add regions first with write_regions!().")
        end
        if DuckDB.num_rows(to_result) == 0
            error("Region '$region_to' not found in database. Add regions first with write_regions!().")
        end
        
        from_id = DuckDB.fetchall(from_result)[1][1]
        to_id = DuckDB.fetchall(to_result)[1][1]
        
        interface_name = "$region_from->$region_to"
        
        # Insert interface (ignore if already exists due to UNIQUE constraint)
        try
            DuckDB.execute(conn, """
                INSERT INTO interfaces (region_from_id, region_to_id, name) 
                VALUES (?, ?, ?)
            """, [from_id, to_id, interface_name])
        catch e
            # Interface already exists, continue
            if !occursin("UNIQUE constraint", string(e))
                rethrow(e)
            end
        end
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
        result = DuckDB.execute(conn, "SELECT id FROM regions WHERE name = ?", [region_name])
        if DuckDB.num_rows(result) == 0
            error("Region '$region_name' not found in database")
        end
        region_id = DuckDB.fetchall(result)[1][1]
        push!(region_ids, region_id)
    end
    
    return region_ids
end

"""
    get_interface_ids_ordered(interface_names::Vector{String}, conn::DuckDB.Connection) -> Vector{Int}

Get interface IDs in the same order as the interface_names array.
Assumes all interfaces exist in the database.
"""
function get_interface_ids_ordered(interface_names::Vector{String}, conn::DuckDB.Connection)
    interface_ids = Vector{Int}()
    
    for interface_name in interface_names
        result = DuckDB.execute(conn, "SELECT id FROM interfaces WHERE name = ?", [interface_name])
        if DuckDB.num_rows(result) == 0
            error("Interface '$interface_name' not found in database")
        end
        interface_id = DuckDB.fetchall(result)[1][1]
        push!(interface_ids, interface_id)
    end
    
    return interface_ids
end

"""
    write_event!(event::Event, conn::DuckDB.Connection) -> Int

Write event record to events table and return the event ID.
"""
function write_event!(event::Event, conn::DuckDB.Connection)
    # Extract start and end timestamps
    start_ts = first(event.timestamps)
    end_ts = last(event.timestamps)
    time_period_count = length(event.timestamps)
    
    # Insert event and get the ID
    DuckDB.execute(conn, """
        INSERT INTO events (name, start_timestamp, end_timestamp, time_period_count) 
        VALUES (?, ?, ?, ?)
    """, [event.name, start_ts, end_ts, time_period_count])
    
    # Get the inserted event ID
    result = DuckDB.execute(conn, "SELECT last_insert_rowid()")
    event_id = DuckDB.fetchall(result)[1][1]
    
    return event_id
end

"""
    write_system_shortfall!(event_id::Int, event::Event, conn::DuckDB.Connection)

Write system-level shortfall metrics to event_system_shortfall table.
"""
function write_system_shortfall!(event_id::Int, event::Event, conn::DuckDB.Connection)
    DuckDB.execute(conn, """
        INSERT INTO event_system_shortfall (event_id, lole, eue, neue) 
        VALUES (?, ?, ?, ?)
    """, [event_id, val(event.system_lole), val(event.system_eue), val(event.system_neue)])
end

"""
    write_regional_shortfall!(event_id::Int, event::Event, region_ids::Vector{Int}, conn::DuckDB.Connection)

Write regional shortfall metrics to event_regional_shortfall table.
"""
function write_regional_shortfall!(event_id::Int, event::Event, region_ids::Vector{Int}, conn::DuckDB.Connection)
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


