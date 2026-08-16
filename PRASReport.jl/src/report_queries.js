window.loadSimulationInfo = async function(conn) {
    const result = await conn.query(`
        SELECT n_samples, step_size, time_unit, power_unit, energy_unit, timesteps,
               start_timestamp, end_timestamp, timezone,
               lole_mean, lole_stderr, neue_mean, neue_stderr,
               eue_mean, eue_stderr
        FROM report_db.systemsiminfo
        LIMIT 1
    `);
    return result.toArray()[0];
};

window.loadSystemEventMetrics = async function(conn) {
    const result = await conn.query(`
        SELECT
            n_events,
            lolev_mean,
            lolev_stderr,
            mean_duration,
            mean_duration_stderr,
            max_duration,
            max_duration_stderr,
            mean_energy,
            mean_energy_stderr,
            max_energy,
            max_energy_stderr
        FROM report_db.event_metrics
        WHERE scope = 'system'
        LIMIT 1
    `);

    return result.toArray()[0];
};

window.loadSystemPlotEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            sample_id,
            duration,
            energy
        FROM report_db.system_shortfall_events
        ORDER BY start_timestamp
    `);

    const rows = result.toArray();

    return {
        duration: rows.map(r => r.duration),
        energy: rows.map(r => r.energy),
        sample_id: rows.map(r => r.sample_id)
    };
};

window.loadRegionalPlotEvents = async function(conn) {
    const result = await conn.query(`
        SELECT
            region_name,
            sample_id,
            duration,
            energy
        FROM report_db.regional_shortfall_events
        ORDER BY region_name, start_timestamp
    `);

    const rows = result.toArray();
    const byRegion = new Map();

    rows.forEach(r => {
        const region = r.region_name || "Unknown";

        if (!byRegion.has(region)) {
            byRegion.set(region, {
                duration: [],
                energy: [],
                sample_id: []
            });
        }

        const group = byRegion.get(region);
        group.duration.push(r.duration);
        group.energy.push(r.energy);
        group.sample_id.push(r.sample_id);
    });

    return byRegion;
};

window.loadRegionalEventMetricsTable = async function(conn) {
    const result = await conn.query(`
        SELECT
            region_name,
            n_events,
            lolev_mean,
            lolev_stderr,
            mean_duration_periods AS mean_duration,
            mean_duration_stderr_periods AS mean_duration_stderr,
            max_duration_periods AS max_duration,
            max_duration_stderr_periods AS max_duration_stderr,
            mean_energy,
            mean_energy_stderr,
            max_energy,
            max_energy_stderr
        FROM report_db.regional_event_metrics
        ORDER BY region_name
    `);
    return result.toArray();
};

window.loadRegionalMCMetrics = async function(conn) {
    const result = await conn.query(`
        SELECT
            region_name,
            eue_mean,
            eue_stderr,
            lole_mean,
            lole_stderr,
            neue_mean,
            neue_stderr
        FROM report_db.regional_adequacy_metrics
        ORDER BY region_name
    `);
    return result.toArray();
};

window.loadSystemShortfallHeatmap = async function(conn) {
    const result = await conn.query(`
        WITH system_shortfall AS (
            SELECT
                timestamp,
                SUM(mean_shortfall) AS mean_shortfall
            FROM report_db.regional_shortfall_timeseries
            GROUP BY timestamp
        )
        SELECT
            month(timestamp) AS month,
            hour(timestamp) AS hour,
            AVG(mean_shortfall) AS mean_shortfall
        FROM system_shortfall
        GROUP BY month, hour
        ORDER BY month, hour
    `);
    return result.toArray();
};

window.loadRegionalShortfallHeatmaps = async function(conn) {
    const result = await conn.query(`
        SELECT
            region_name,
            month(timestamp) AS month,
            hour(timestamp) AS hour,
            AVG(mean_shortfall) AS mean_shortfall
        FROM report_db.regional_shortfall_timeseries
        GROUP BY region_name, month, hour
        ORDER BY region_name, month, hour
    `);
    return result.toArray();
};

window.hasFullYearShortfallHeatmapData = async function(conn) {
    const result = await conn.query(`
        SELECT COUNT(DISTINCT month(timestamp)) AS n_months
        FROM report_db.regional_shortfall_timeseries
    `);

    return Number(result.toArray()[0].n_months) === 12;
};

window.loadSystemNEUEHeatmap = async function(conn) {
    const result = await conn.query(`
        WITH system_by_timestamp AS (
            SELECT
                s.timestamp,
                SUM(s.mean_shortfall) AS mean_shortfall,
                SUM(l.load) AS load
            FROM report_db.shortfall_mean_timeseries s
            JOIN report_db.load_timeseries l
                ON s.timestamp = l.timestamp
               AND s.region_id = l.region_id
            GROUP BY s.timestamp
        ),
        neue_by_timestamp AS (
            SELECT
                timestamp,
                CASE
                    WHEN load > 0 THEN mean_shortfall / (load / 1e6)
                    ELSE 0
                END AS neue
            FROM system_by_timestamp
        )
        SELECT
            month(timestamp) AS month,
            hour(timestamp) AS hour,
            AVG(neue) AS neue
        FROM neue_by_timestamp
        GROUP BY month, hour
        ORDER BY month, hour
    `);
    return result.toArray();
};

window.loadSystemShortfallTimeseries = async function(conn) {
    const result = await conn.query(`
        SELECT
            timestamp,
            SUM(mean_shortfall) AS mean_shortfall
        FROM report_db.regional_shortfall_timeseries
        GROUP BY timestamp
        ORDER BY timestamp
    `);
    return result.toArray();
};

window.loadInterfaceFlowTimeseries = async function(conn) {
    const result = await conn.query(`
        SELECT
            timestamp,
            interface_id,
            interface_name,
            mean_flow
        FROM report_db.interface_flow_timeseries
        ORDER BY interface_name, timestamp
    `);
    return result.toArray();
};

window.loadInterfaceUtilizationTimeseries = async function(conn) {
    const result = await conn.query(`
        SELECT
            timestamp,
            interface_id,
            interface_name,
            utilization
        FROM report_db.interface_utilization_timeseries
        ORDER BY interface_name, timestamp
    `);
    return result.toArray();
};
