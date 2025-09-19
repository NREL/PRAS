module PRASReport

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                         Generators, Storages, GeneratorStorages, Lines,
                         timeunits, powerunits, energyunits, unitsymbol             

import PRASCore.Simulations: assess

import PRASCore.Results: EUE, LOLE, NEUE, ShortfallResult, FlowResult,
                         ShortfallSamplesResult, AbstractShortfallResult, 
                         Result, MeanEstimate, findfirstunique,
                         val, stderror
import StatsBase: mean
import Dates: @dateformat_str, format, now
import TimeZones: ZonedDateTime

using DuckDB
using Base64
using JSON3

include("events.jl")

export Event, get_events, event_length

end # module PRASReport
