# PRASReport.jl

`PRASReport.jl` provides functionality to generate an interactive HTML report from PRAS simulation results.

The report includes:
- Monte Carlo average system and regional metrics
- Event-based system and regional metrics
- The most commonly used plots in analysis both at the system and regional level

## Usage

An example showcasing how to create a report can be found at:

`PRASReport.jl/examples/run_report.jl`

And an example output report for a modified version of RTS-GMLC can be found at:

`PRASReport.jl/examples/example_rts_report.html`

## Querying Report Data

Each generated report is accompanied by a DuckDB database with the same base name.
The database contains normalized source tables and the following user-facing views:

| View | Contents |
| --- | --- |
| `system_shortfall_events` | System-level shortfall events with timestamps, converted durations and units |
| `regional_shortfall_events` | Regional shortfall events with region names, timestamps, converted durations and units |
| `regional_event_metrics` | Regional event metrics with region names and units |
| `regional_adequacy_metrics` | Regional EUE, LOLE and NEUE results with region names and units |
| `regional_shortfall_timeseries` | Mean shortfall by timestamp and region name |
| `interface_flow_timeseries` | Mean flow by timestamp and named interface |
| `interface_utilization_timeseries` | Mean utilization by timestamp and named interface |
| `regional_load_timeseries` | Load by timestamp and region name |

The views are read-only queries over the normalized tables so they do not duplicate database data.
For example, the largest regional shortfall events can be inspected with:

```sql
SELECT
    sample_id,
    region_name,
    start_timestamp,
    end_timestamp,
    duration,
    duration_unit,
    energy,
    energy_unit
FROM regional_shortfall_events
ORDER BY energy DESC
LIMIT 20;
```
