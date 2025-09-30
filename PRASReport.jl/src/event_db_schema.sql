-- System and Simulation parameters 
CREATE TABLE systemsiminfo (
    timesteps INTEGER,
    step_size INTEGER NOT NULL,
    time_unit TEXT NOT NULL,
    power_unit TEXT NOT NULL,
    energy_unit TEXT NOT NULL,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE,
    timezone TEXT,
    n_samples INTEGER,
    eue_mean REAL NOT NULL,
    eue_stderr REAL NOT NULL,
    lole_mean REAL NOT NULL,
    lole_stderr REAL NOT NULL,
    neue_mean REAL NOT NULL,
    neue_stderr REAL NOT NULL,
    eventthreshold INTEGER NOT NULL,
    
    -- Constraint to ensure valid ISO 8601 duration units
    CONSTRAINT valid_time_unit CHECK (
        time_unit IN ('Year', 'Day', 'Hour', 'Minute', 'Second')
    )
);

-- Regions lookup table
CREATE TABLE regions (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- Interfaces lookup table (region to region connections)
CREATE TABLE interfaces (
    id INTEGER PRIMARY KEY,
    region_from_id INTEGER REFERENCES regions(id),
    region_to_id INTEGER REFERENCES regions(id),
    name TEXT, -- name like "Region1->Region2"
    UNIQUE(region_from_id, region_to_id)
);

-- Main events table (clean, no parameters)
CREATE SEQUENCE eventid_sequence START 1;
CREATE TABLE events (
    id INTEGER PRIMARY KEY DEFAULT nextval('eventid_sequence'),
    name TEXT NOT NULL,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    time_period_count INTEGER NOT NULL   -- N parameter
);

-- System-level metrics for each event (aggregated)
CREATE TABLE event_system_shortfall (
    event_id INTEGER REFERENCES events(id),
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    PRIMARY KEY (event_id)
);

-- Regional metrics for each event (aggregated)
CREATE TABLE event_regional_shortfall (
    id INTEGER PRIMARY KEY,
    event_id INTEGER REFERENCES events(id),
    region_id INTEGER REFERENCES regions(id),
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    UNIQUE(event_id, region_id)
);

-- Time-series metrics for each timestamp within an event (from sf_ts struct)
-- Optimized with better data types and ordering for columnar storage
CREATE TABLE event_timeseries_shortfall (
    event_id INTEGER NOT NULL,
    region_id INTEGER NOT NULL,
    timestamp_value TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    lole REAL NOT NULL,
    eue REAL NOT NULL,
    neue REAL NOT NULL,
    FOREIGN KEY (event_id) REFERENCES events(id),
    FOREIGN KEY (region_id) REFERENCES regions(id),
    PRIMARY KEY (event_id, region_id, timestamp_value)
);

-- Flow data for each timestamp within an event (from flow_ts struct)
-- Optimized with better data types and ordering for columnar storage
CREATE TABLE event_timeseries_flows (
    event_id INTEGER NOT NULL,
    interface_id INTEGER NOT NULL,
    timestamp_value TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    flow REAL NOT NULL, -- Flow value (NEUE units)
    FOREIGN KEY (event_id) REFERENCES events(id),
    FOREIGN KEY (interface_id) REFERENCES interfaces(id),
    PRIMARY KEY (event_id, interface_id, timestamp_value)
);

-- Optimized indexes for common access patterns
-- Compound indexes for filtering and joining patterns
CREATE INDEX idx_events_timestamps ON events(start_timestamp, end_timestamp);
CREATE INDEX idx_events_name ON events(name); -- For event name lookups

-- Regional metrics - optimize for both directions
CREATE INDEX idx_regional_shortfall_event_region ON event_regional_shortfall(event_id, region_id);
CREATE INDEX idx_regional_shortfall_region_event ON event_regional_shortfall(region_id, event_id);

-- Time-series metrics - optimize for common query patterns
CREATE INDEX idx_timeseries_shortfall_event_time ON event_timeseries_shortfall(event_id, timestamp_value);
CREATE INDEX idx_timeseries_shortfall_region_time ON event_timeseries_shortfall(region_id, timestamp_value);
CREATE INDEX idx_timeseries_shortfall_time_region ON event_timeseries_shortfall(timestamp_value, region_id);

-- Flow metrics - optimize for interface and time queries
CREATE INDEX idx_timeseries_flows_event_time ON event_timeseries_flows(event_id, timestamp_value);
CREATE INDEX idx_timeseries_flows_interface_time ON event_timeseries_flows(interface_id, timestamp_value);

-- Interface lookups
CREATE INDEX idx_interfaces_regions ON interfaces(region_from_id, region_to_id);
CREATE INDEX idx_interfaces_reverse ON interfaces(region_to_id, region_from_id);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Complete event summary with system and regional metrics
CREATE VIEW event_summary AS
SELECT 
    e.id,
    e.name,
    e.start_timestamp,
    e.end_timestamp,
    e.time_period_count AS event_duration_hours,
    esm.lole AS system_lole,
    esm.eue AS system_eue,
    esm.neue AS system_neue,
    COUNT(erm.region_id) AS num_regions
FROM events e
JOIN event_system_shortfall esm ON e.id = esm.event_id
LEFT JOIN event_regional_shortfall erm ON e.id = erm.event_id
GROUP BY e.id, e.name, e.start_timestamp, e.end_timestamp, e.time_period_count,
         esm.lole, esm.eue, esm.neue;

-- Regional breakdown for all events
CREATE VIEW event_regional_breakdown AS
SELECT 
    e.id AS event_id,
    e.name AS event_name,
    r.name AS region_name,
    erm.lole,
    erm.eue,
    erm.neue,
    ROUND(erm.eue / esm.eue * 100, 2) AS eue_percentage_of_system
FROM events e
JOIN event_regional_shortfall erm ON e.id = erm.event_id
JOIN regions r ON erm.region_id = r.id
JOIN event_system_shortfall esm ON e.id = esm.event_id;

-- Time series data with event and region names
CREATE VIEW event_timeseries_detailed AS
SELECT 
    e.id AS event_id,
    e.name AS event_name,
    r.name AS region_name,
    etsm.timestamp_value,
    etsm.lole,
    etsm.eue,
    etsm.neue
FROM events e
JOIN event_timeseries_shortfall etsm ON e.id = etsm.event_id
JOIN regions r ON etsm.region_id = r.id
ORDER BY e.id, r.name, etsm.timestamp_value;

-- Flow data with interface details
CREATE VIEW event_flows_detailed AS
SELECT 
    e.id AS event_id,
    e.name AS event_name,
    rf.name AS region_from,
    rt.name AS region_to,
    i.name AS interface_name,
    etf.timestamp_value,
    etf.flow
FROM events e
JOIN event_timeseries_flows etf ON e.id = etf.event_id
JOIN interfaces i ON etf.interface_id = i.id
JOIN regions rf ON i.region_from_id = rf.id
JOIN regions rt ON i.region_to_id = rt.id
ORDER BY e.id, i.name, etf.timestamp_value;

-- Event rankings by severity (highest EUE first)
CREATE VIEW events_by_severity AS
SELECT 
    e.id,
    e.name,
    e.start_timestamp,
    e.end_timestamp,
    esm.eue AS system_eue,
    esm.lole AS system_lole,
    esm.neue AS system_neue,
    RANK() OVER (ORDER BY esm.eue DESC) AS severity_rank
FROM events e
JOIN event_system_shortfall esm ON e.id = esm.event_id;

-- Monthly event statistics
CREATE VIEW monthly_event_stats AS
SELECT 
    DATE_PART('year', e.start_timestamp) AS year,
    DATE_PART('month', e.start_timestamp) AS month,
    COUNT(*) AS event_count,
    AVG(esm.eue) AS avg_eue,
    SUM(esm.eue) AS total_eue,
    MAX(esm.eue) AS max_eue,
    AVG(DATE_PART('hour', e.end_timestamp - e.start_timestamp) + 1) AS avg_duration_hours
FROM events e
JOIN event_system_shortfall esm ON e.id = esm.event_id
GROUP BY DATE_PART('year', e.start_timestamp), DATE_PART('month', e.start_timestamp)
ORDER BY year, month;

-- Regional contribution analysis
CREATE VIEW regional_contribution_summary AS
SELECT 
    r.name AS region_name,
    COUNT(erm.event_id) AS events_participated,
    AVG(erm.eue) AS avg_regional_eue,
    SUM(erm.eue) AS total_regional_eue,
    AVG(erm.eue / esm.eue * 100) AS avg_contribution_percentage
FROM regions r
JOIN event_regional_shortfall erm ON r.id = erm.region_id
JOIN event_system_shortfall esm ON erm.event_id = esm.event_id
GROUP BY r.name
ORDER BY total_regional_eue DESC;

-- Interface flow summary
CREATE VIEW interface_flow_summary AS
SELECT 
    rf.name AS region_from,
    rt.name AS region_to,
    i.name AS interface_name,
    COUNT(etf.event_id) AS events_with_flow,
    AVG(etf.flow) AS avg_flow,
    MAX(etf.flow) AS max_flow,
    MIN(etf.flow) AS min_flow,
    SUM(etf.flow) AS total_flow
FROM interfaces i
JOIN regions rf ON i.region_from_id = rf.id
JOIN regions rt ON i.region_to_id = rt.id
JOIN event_timeseries_flows etf ON i.id = etf.interface_id
GROUP BY rf.name, rt.name, i.name
ORDER BY total_flow DESC;

-- Event EUE matrix view - easy subsetting for specific events
CREATE VIEW event_eue_matrix AS
SELECT 
    e.id AS event_id,
    e.name AS event_name,
    etsm.timestamp_value,
    r.name AS region_name,
    etsm.eue
FROM events e
JOIN event_timeseries_shortfall etsm ON e.id = etsm.event_id
JOIN regions r ON etsm.region_id = r.id
ORDER BY e.id, etsm.timestamp_value, r.name;