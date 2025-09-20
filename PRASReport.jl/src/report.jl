function run_reports(sim::Simulation; kwargs...)
    return assess(sim; kwargs...)
end

"""
    get_db(sf::ShortfallResult, flow::FlowResult=nothing, conn::DuckDB.Connection; kwargs...)

Extract events from PRAS results and write them to database.
Returns the event IDs for further processing.
"""
function get_db(sf::ShortfallResult{N,L,T,E},
                conn::DuckDB.Connection,
                flow::FlowResult{N,L,T,P}=nothing; 
                kwargs...) where {N,L,T,P,E}
    
    # Extract events from shortfall results
    events = get_events(sf; kwargs...)
    
    # Write events to database (events, system metrics, regional metrics)
    event_ids = write_db!(events, conn)
    
    # Write time-series shortfall data for each event
    sf_timeseries_allevents = Shortfall_timeseries.(events, sf)
    write_db!.(sf_timeseries_allevents, conn)
    
    # Write flow data if provided
    if !isnothing(flow)
        flow_timeseries_allevents = Flow_timeseries.(events, flow) # You'll need to implement this
        write_db!.(flow_timeseries_allevents, conn)
    end
    
    return event_ids
end

"""
    write_db!(events::Vector{Event}, conn::DuckDB.Connection) -> Vector{Int}

Write a vector of events to database and return their event IDs.
"""
function write_db!(events::Vector{Event}, conn::DuckDB.Connection)
    event_ids = Vector{Int}()
    for event in events
        event_id = write_db!(event, conn)
        push!(event_ids, event_id)
    end
    return event_ids
end