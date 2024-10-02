#######################################################
# Surya
# NREL
# August 2022
# SIIP --> PRAS Linkage Module
#######################################################
# To use this functionality a user has to install PowerSystems(currently 3),
# CSV,DataFrames,InteractiveUtils,JSON in their project and load these
# after loading PRAS to pass in a PRAS system with the assess function.
# This has been tested with Area aggregation but fails with LoadZone level
# aggregation.
#######################################################
module PSY2PRAS
#################################################################################
# Exports
#################################################################################
export make_pras_system
export generate_outage_profile
export generate_csv_outage_profile
export add_csv_time_series!
export add_csv_time_series_single_stage!
#################################################################################
# Imports
#################################################################################
import PowerSystems
import PRAS
import Dates
import TimeZones
import DataFrames
import CSV
import JSON
import InteractiveUtils

const PSY = PowerSystems
const IU = InteractiveUtils
#################################################################################
# Includes
#################################################################################
include("parsers/power_system_table_data.jl") # Over-writes some PSY functions.
include("S2P.jl")
include("util/add_csv_time_series_data.jl")
include("util/runchecks.jl")
end