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
    neue_stderr REAL NOT NULL
    
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

CREATE TABLE shortfall_events (
    id INTEGER PRIMARY KEY,
    sample_id INTEGER NOT NULL,
    scope TEXT NOT NULL,
    region_id INTEGER,
    start_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    end_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    duration_periods INTEGER NOT NULL,
    energy REAL NOT NULL
);

CREATE TABLE event_metrics (
    scope TEXT NOT NULL,
    region_id INTEGER REFERENCES regions(id),
    n_events INTEGER NOT NULL,

    lolev_mean REAL NOT NULL,
    lolev_stderr REAL NOT NULL,

    mean_duration REAL NOT NULL,
    mean_duration_stderr REAL NOT NULL,

    max_duration REAL NOT NULL,
    max_duration_stderr REAL NOT NULL,

    mean_energy REAL NOT NULL,
    mean_energy_stderr REAL NOT NULL,

    max_energy REAL NOT NULL,
    max_energy_stderr REAL NOT NULL
);

CREATE TABLE mc_regional_metrics (
    region_id INTEGER REFERENCES regions(id),
    eue_mean REAL NOT NULL,
    eue_stderr REAL NOT NULL,
    lole_mean REAL NOT NULL,
    lole_stderr REAL NOT NULL,
    neue_mean REAL NOT NULL,
    neue_stderr REAL NOT NULL
);

CREATE TABLE shortfall_mean_timeseries (
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    region_id INTEGER REFERENCES regions(id),
    mean_shortfall REAL NOT NULL
);

CREATE TABLE flow_mean_timeseries (
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    interface_id INTEGER REFERENCES interfaces(id),
    mean_flow REAL NOT NULL
);

CREATE TABLE utilization_mean_timeseries (
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    interface_id INTEGER REFERENCES interfaces(id),
    utilization REAL NOT NULL
);

CREATE TABLE load_timeseries (
    timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    region_id INTEGER REFERENCES regions(id),
    load REAL NOT NULL
);

-- User-facing views with descriptive names and units
CREATE VIEW system_shortfall_events AS
SELECT
    e.id AS event_id,
    e.sample_id,
    e.start_timestamp,
    e.end_timestamp,
    e.duration_periods,
    e.duration_periods * s.step_size AS duration,
    s.time_unit AS duration_unit,
    CAST(e.energy AS DOUBLE) AS energy,
    s.energy_unit
FROM shortfall_events e
CROSS JOIN (
    SELECT step_size, time_unit, energy_unit
    FROM systemsiminfo
    LIMIT 1
) s
WHERE e.scope = 'system';

CREATE VIEW regional_shortfall_events AS
SELECT
    e.id AS event_id,
    e.sample_id,
    r.name AS region_name,
    e.start_timestamp,
    e.end_timestamp,
    e.duration_periods,
    e.duration_periods * s.step_size AS duration,
    s.time_unit AS duration_unit,
    CAST(e.energy AS DOUBLE) AS energy,
    s.energy_unit
FROM shortfall_events e
JOIN regions r ON e.region_id = r.id
CROSS JOIN (
    SELECT step_size, time_unit, energy_unit
    FROM systemsiminfo
    LIMIT 1
) s
WHERE e.scope = 'region';

CREATE VIEW regional_event_metrics AS
SELECT
    r.name AS region_name,
    m.n_events,
    m.lolev_mean,
    m.lolev_stderr,
    m.mean_duration AS mean_duration_periods,
    m.mean_duration_stderr AS mean_duration_stderr_periods,
    m.mean_duration * s.step_size AS mean_duration,
    m.mean_duration_stderr * s.step_size AS mean_duration_stderr,
    m.max_duration AS max_duration_periods,
    m.max_duration_stderr AS max_duration_stderr_periods,
    m.max_duration * s.step_size AS max_duration,
    m.max_duration_stderr * s.step_size AS max_duration_stderr,
    s.time_unit AS duration_unit,
    m.mean_energy,
    m.mean_energy_stderr,
    m.max_energy,
    m.max_energy_stderr,
    s.energy_unit
FROM event_metrics m
JOIN regions r ON m.region_id = r.id
CROSS JOIN (
    SELECT step_size, time_unit, energy_unit
    FROM systemsiminfo
    LIMIT 1
) s
WHERE m.scope = 'region';

CREATE VIEW regional_adequacy_metrics AS
SELECT
    r.name AS region_name,
    m.eue_mean,
    m.eue_stderr,
    m.lole_mean,
    m.lole_stderr,
    m.neue_mean,
    m.neue_stderr,
    s.energy_unit,
    s.time_unit
FROM mc_regional_metrics m
JOIN regions r ON m.region_id = r.id
CROSS JOIN (
    SELECT energy_unit, time_unit
    FROM systemsiminfo
    LIMIT 1
) s;

CREATE VIEW regional_shortfall_timeseries AS
SELECT
    shortfall.timestamp,
    r.name AS region_name,
    shortfall.mean_shortfall,
    s.power_unit
FROM shortfall_mean_timeseries shortfall
JOIN regions r ON shortfall.region_id = r.id
CROSS JOIN (
    SELECT power_unit
    FROM systemsiminfo
    LIMIT 1
) s;

CREATE VIEW interface_flow_timeseries AS
SELECT
    flow.timestamp,
    i.id AS interface_id,
    i.name AS interface_name,
    flow.mean_flow,
    (
        SELECT power_unit
        FROM systemsiminfo
        LIMIT 1
    ) AS power_unit
FROM flow_mean_timeseries flow
JOIN interfaces i ON flow.interface_id = i.id;

CREATE VIEW interface_utilization_timeseries AS
SELECT
    utilization.timestamp,
    i.id AS interface_id,
    i.name AS interface_name,
    utilization.utilization
FROM utilization_mean_timeseries utilization
JOIN interfaces i ON utilization.interface_id = i.id;

CREATE VIEW regional_load_timeseries AS
SELECT
    regional_load.timestamp,
    r.name AS region_name,
    regional_load.load,
    s.power_unit
FROM load_timeseries regional_load
JOIN regions r ON regional_load.region_id = r.id
CROSS JOIN (
    SELECT power_unit
    FROM systemsiminfo
    LIMIT 1
) s;
