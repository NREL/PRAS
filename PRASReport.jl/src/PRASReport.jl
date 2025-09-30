module PRASReport

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                            Generators, Storages, GeneratorStorages, Lines,
                            timeunits, powerunits, energyunits, unitsymbol,
                            unitsymbol_long             
import PRASCore.Simulations: assess
import PRASCore.Results: EUE, LOLE, NEUE, ShortfallResult, FlowResult,
                            ShortfallSamplesResult, AbstractShortfallResult, 
                            Result, MeanEstimate, findfirstunique,
                            val, stderror
import StatsBase: mean
import Dates: @dateformat_str, format, now, DateTime
import TimeZones: ZonedDateTime, @tz_str, TimeZone
import Base64: base64encode
import Tables: columntable
import DuckDB

include("events.jl")
include("writedb.jl")
include("report.jl")

export Event, get_events, event_length, Shortfall_timeseries, Flow_timeseries
export write_db!, get_db, write_regions!, write_interfaces!
export create_html_report

end # module PRASReport
