##############################################
# Definitions
#############################################
const POWER_SYSTEM_DESCRIPTOR_FILE =
    joinpath(@__DIR__, "descriptors", "power_system_inputs.json")

const GENERATOR_MAPPING_FILE =
    joinpath(@__DIR__, "descriptors", "generator_mapping.yaml")
##############################################
# Struct for outage information
##############################################
struct outage_info
    outage_probability::Float64
    recovery_probability::Float64

    outage_info(outage_probability = 0.0, recovery_probability = 1.0) =
        new(outage_probability, recovery_probability)
end
##############################################
# Converting FOR and MTTR to λ and μ
##############################################
function outage_to_rate(outage_data::Tuple{Float64, Int64})
    for_gen = outage_data[1]
    mttr = outage_data[2]

    if (for_gen >1.0)
        for_gen = for_gen/100
    end

    if (mttr != 0)
        μ = 1 / mttr
    else
        μ = 0.0
    end
    λ = (μ * for_gen) / (1 - for_gen)
    #λ = for_gen

    return (λ = λ, μ = μ)
end
##############################################
# PowerSystems2PRAS definition of 
# PowerSystemTableData()
##############################################
function PSY.PowerSystemTableData(
    data::Dict{String, Any},
    directory::String,
    user_descriptors::Union{String, Dict},
    descriptors::Union{String, Dict},
    generator_mapping::Union{String, Dict};
    timeseries_metadata_file = joinpath(directory, "timeseries_pointers"),
)
    category_to_df = Dict{PSY.InputCategory, DataFrames.DataFrame}()

    if !haskey(data, "bus")
        throw(PSY.DataFormatError("key 'bus' not found in input data"))
    end

    if !haskey(data, "base_power")
        @warn "key 'base_power' not found in input data; using default=$(PSY.DEFAULT_BASE_MVA)"
    end
    base_power = get(data, "base_power", PSY.DEFAULT_BASE_MVA)

    for (name, category) in PSY.INPUT_CATEGORY_NAMES
        val = get(data, name, nothing)
        if isnothing(val)
            @debug "key '$name' not found in input data, set to nothing"
        else
            category_to_df[category] = val
        end
    end

    if !isfile(timeseries_metadata_file)
        if isfile(string(timeseries_metadata_file, ".json"))
            timeseries_metadata_file = string(timeseries_metadata_file, ".json")
        elseif isfile(string(timeseries_metadata_file, ".csv"))
            timeseries_metadata_file = string(timeseries_metadata_file, ".csv")
        else
            timeseries_metadata_file = nothing
        end
    end

    if user_descriptors isa AbstractString
        user_descriptors = PSY._read_config_file(user_descriptors)
    end

    if descriptors isa AbstractString
        descriptors = PSY._read_config_file(descriptors)
    end

    if generator_mapping isa AbstractString
        generator_mapping = PSY.get_generator_mapping(generator_mapping)
    end

    return PSY.PowerSystemTableData(
        base_power,
        category_to_df,
        timeseries_metadata_file,
        directory,
        user_descriptors,
        descriptors,
        generator_mapping,
    )
end
##############################################
# PowerSystems2PRAS definition of 
# PowerSystemTableData()
##############################################
"""
Reads in all the data stored in csv files
The general format for data is
    folder:
        gen.csv
        branch.csv
        bus.csv
        ..
        load.csv

# Arguments
- `directory::AbstractString`: directory containing CSV files
- `base_power::Float64`: base power for System
- `user_descriptor_file::AbstractString`: customized input descriptor file
- `descriptor_file=POWER_SYSTEM_DESCRIPTOR_FILE`: PowerSystems descriptor file
- `generator_mapping_file=GENERATOR_MAPPING_FILE`: generator mapping configuration file
"""
function PSY.PowerSystemTableData(
    directory::AbstractString,
    base_power::Float64,
    user_descriptor_file::AbstractString;
    descriptor_file = POWER_SYSTEM_DESCRIPTOR_FILE,
    generator_mapping_file = GENERATOR_MAPPING_FILE,
    timeseries_metadata_file = joinpath(directory, "timeseries_pointers"),
)
    files = readdir(directory)
    REGEX_DEVICE_TYPE = r"(.*?)\.csv"
    REGEX_IS_FOLDER = r"^[A-Za-z]+$"
    data = Dict{String, Any}()

    if length(files) == 0
        error("No files in the folder")
    else
        data["base_power"] = base_power
    end

    encountered_files = 0
    for d_file in files
        try
            if match(REGEX_IS_FOLDER, d_file) !== nothing
                @info "Parsing csv files in $d_file ..."
                d_file_data = Dict{String, Any}()
                for file in readdir(joinpath(directory, d_file))
                    if match(REGEX_DEVICE_TYPE, file) !== nothing
                        @info "Parsing csv data in $file ..."
                        encountered_files += 1
                        fpath = joinpath(directory, d_file, file)
                        raw_data = DataFrames.DataFrame(CSV.File(fpath))
                        d_file_data[split(file, r"[.]")[1]] = raw_data
                    end
                end

                if length(d_file_data) > 0
                    data[d_file] = d_file_data
                    @info "Successfully parsed $d_file"
                end

            elseif match(REGEX_DEVICE_TYPE, d_file) !== nothing
                @info "Parsing csv data in $d_file ..."
                encountered_files += 1
                fpath = joinpath(directory, d_file)
                raw_data = DataFrames.DataFrame(CSV.File(fpath))
                data[split(d_file, r"[.]")[1]] = raw_data
                @info "Successfully parsed $d_file"
            end
        catch ex
            @error "Error occurred while parsing $d_file" exception = ex
            throw(ex)
        end
    end
    if encountered_files == 0
        error("No csv files or folders in $directory")
    end

    return PSY.PowerSystemTableData(
        data,
        directory,
        user_descriptor_file,
        descriptor_file,
        generator_mapping_file,
        timeseries_metadata_file = timeseries_metadata_file,
    )
end
##############################################
# PowerSystems2PRAS definition of System()
##############################################
"""
Construct a System from PowerSystemTableData data.

# Arguments
- `time_series_resolution::Union{DateTime, Nothing}=nothing`: only store time_series that match
  this resolution.
- `time_series_in_memory::Bool=false`: Store time series data in memory instead of HDF5 file
- `time_series_directory=nothing`: Store time series data in directory instead of tmpfs
- `runchecks::Bool=true`: Validate struct fields.

Throws DataFormatError if time_series with multiple resolutions are detected.
- A time_series has a different resolution than others.
- A time_series has a different horizon than others.

"""
function PSY.System(
    data::PSY.PowerSystemTableData;
    time_series_resolution = nothing,
    time_series_in_memory = false,
    time_series_directory = nothing,
    runchecks = true,
    kwargs...,
)
    sys = PSY.System(
        data.base_power;
        time_series_in_memory = time_series_in_memory,
        time_series_directory = time_series_directory,
        runchecks = runchecks,
        kwargs...,
    )
    PSY.set_units_base_system!(sys, PSY.IS.UnitSystem.DEVICE_BASE)

    PSY.loadzone_csv_parser!(sys, data)
    PSY.bus_csv_parser!(sys, data)

    # Services and time_series must be last.
    parsers = (
        (PSY.get_dataframe(data, PSY.InputCategory.BRANCH), PSY.branch_csv_parser!),
        (PSY.get_dataframe(data, PSY.InputCategory.DC_BRANCH), PSY.dc_branch_csv_parser!),
        (PSY.get_dataframe(data, PSY.InputCategory.GENERATOR), PSY.gen_csv_parser!),
        (PSY.get_dataframe(data, PSY.InputCategory.LOAD), PSY.load_csv_parser!),
        (PSY.get_dataframe(data, PSY.InputCategory.RESERVE), PSY.services_csv_parser!),
    )

    for (val, parser) in parsers
        if !isnothing(val)
            parser(sys, data)
        end
    end

    timeseries_metadata_file =
        get(kwargs, :timeseries_metadata_file, getfield(data, :timeseries_metadata_file))

    if !isnothing(timeseries_metadata_file)
        PSY.add_time_series!(sys, timeseries_metadata_file; resolution = time_series_resolution)
    end

    PSY.check(sys)
    return sys
end
##############################################
# PowerSystems2PRAS definition of make_generator()
##############################################
"""Creates a generator of any type."""
function PSY.make_generator(data::PSY.PowerSystemTableData, gen, cost_colnames, bus, gen_storage)
    generator = nothing
    gen_type =
        PSY.get_generator_type(gen.fuel, get(gen, :unit_type, nothing), data.generator_mapping)

    if isnothing(gen_type)
        @error "Cannot recognize generator type" gen.name
    elseif gen_type == PSY.ThermalStandard
        generator = PSY.make_thermal_generator(data, gen, cost_colnames, bus)
    elseif gen_type == PSY.ThermalMultiStart
        generator = PSY.make_thermal_generator_multistart(data, gen, cost_colnames, bus)
    elseif gen_type <: PSY.HydroGen
        generator = PSY.make_hydro_generator(gen_type, data, gen, cost_colnames, bus, gen_storage)
    elseif gen_type <: PSY.RenewableGen
        generator = PSY.make_renewable_generator(gen_type, data, gen, cost_colnames, bus)
    elseif gen_type == PSY.GenericBattery
        head_dict, _ = gen_storage
        if !haskey(head_dict, gen.name)
            throw(PSY.DataFormatError("Cannot find storage for $(gen.name) in storage.csv"))
        end
        storage = head_dict[gen.name]
        generator = PSY.make_storage(data, gen, bus, storage)
    else
        @error "Skipping unsupported generator" gen.name gen_type
    end

    return generator
end
##############################################
# PowerSystems2PRAS function to add outage info 
# to Generator
##############################################
function add_outage_info!(component::PSY.StaticInjection, gen)
    outage_rates = outage_to_rate((parse(Float64,gen.fotr),round(Int,parse(Float64,gen.mttr))))
    outage_probability = outage_info(outage_rates.λ, outage_rates.μ)

    ext = PSY.get_ext(component)
    for fn in fieldnames(outage_info)
        ext[string(fn)] = getfield(outage_probability, fn)
    end
end
##############################################
# PowerSystems2PRAS definition of make_thermal_generator()
##############################################
function PSY.make_thermal_generator(data::PSY.PowerSystemTableData, gen, cost_colnames, bus)
    @debug "Making ThermaStandard" _group = PSY.IS.LOG_GROUP_PARSING gen.name
    active_power_limits =
        (min = gen.active_power_limits_min, max = gen.active_power_limits_max)
    (reactive_power, reactive_power_limits) = PSY.make_reactive_params(gen)
    rating = PSY.calculate_rating(active_power_limits, reactive_power_limits)
    ramplimits = PSY.make_ramplimits(gen)
    timelimits = PSY.make_timelimits(gen, :min_up_time, :min_down_time)
    primemover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type)
    fuel = PSY.parse_enum_mapping(PSY.ThermalFuels, gen.fuel)

    base_power = gen.base_mva
    var_cost, fixed, fuel_cost =
        PSY.calculate_variable_cost(data, gen, cost_colnames, base_power)
    startup_cost, shutdown_cost = PSY.calculate_uc_cost(data, gen, fuel_cost)
    op_cost = PSY.ThreePartCost(var_cost, fixed, startup_cost, shutdown_cost)

    component = PSY.ThermalStandard(
        name = gen.name,
        available = gen.available,
        status = gen.status_at_start,
        bus = bus,
        active_power = gen.active_power,
        reactive_power = reactive_power,
        rating = rating,
        prime_mover = primemover,
        fuel = fuel,
        active_power_limits = active_power_limits,
        reactive_power_limits = reactive_power_limits,
        ramp_limits = ramplimits,
        time_limits = timelimits,
        operation_cost = op_cost,
        base_power = base_power,
    )

    if ((gen.fotr, gen.mttr) != (nothing, nothing))
        add_outage_info!(component, gen)
    end

    return component
end
##############################################
# PowerSystems2PRAS definition of make_thermal_generator_multistart()
##############################################
function PSY.make_thermal_generator_multistart(
    data::PSY.PowerSystemTableData,
    gen,
    cost_colnames,
    bus,
)
    thermal_gen = PSY.make_thermal_generator(data, gen, cost_colnames, bus)

    @debug "Making ThermalMultiStart" _group = PSY.IS.LOG_GROUP_PARSING gen.name
    base_power = PSY.get_base_power(thermal_gen)
    var_cost, fixed, fuel_cost =
        PSY.calculate_variable_cost(data, gen, cost_colnames, base_power)
    if var_cost isa Float64
        no_load_cost = 0.0
        var_cost = PSY.VariableCost(var_cost)
    else
        no_load_cost = var_cost[1][1]
        var_cost =
        PSY.VariableCost([(c - no_load_cost, pp - var_cost[1][2]) for (c, pp) in var_cost])
    end
    lag_hot =
        isnothing(gen.hot_start_time) ? PSY.get_time_limits(thermal_gen).down :
        gen.hot_start_time
    lag_warm = isnothing(gen.warm_start_time) ? 0.0 : gen.warm_start_time
    lag_cold = isnothing(gen.cold_start_time) ? 0.0 : gen.cold_start_time
    startup_timelimits = (hot = lag_hot, warm = lag_warm, cold = lag_cold)
    start_types = sum(values(startup_timelimits) .> 0.0)
    startup_ramp = isnothing(gen.startup_ramp) ? 0.0 : gen.startup_ramp
    shutdown_ramp = isnothing(gen.shutdown_ramp) ? 0.0 : gen.shutdown_ramp
    power_trajectory = (startup = startup_ramp, shutdown = shutdown_ramp)
    hot_start_cost = isnothing(gen.hot_start_cost) ? gen.startup_cost : gen.hot_start_cost
    if isnothing(hot_start_cost)
        if hasfield(typeof(gen), :startup_heat_cold_cost)
            hot_start_cost = gen.startup_heat_cold_cost * fuel_cost * 1000
        else
            hot_start_cost = 0.0
            @warn "No hot_start_cost or startup_cost defined for $(gen.name), setting to $startup_cost" maxlog =
                5
        end
    end
    warm_start_cost = isnothing(gen.warm_start_cost) ? PSY.START_COST : gen.hot_start_cost #TODO
    cold_start_cost = isnothing(gen.cold_start_cost) ? PSY.START_COST : gen.cold_start_cost
    startup_cost = (hot = hot_start_cost, warm = warm_start_cost, cold = cold_start_cost)

    shutdown_cost = gen.shutdown_cost
    if isnothing(shutdown_cost)
        @warn "No shutdown_cost defined for $(gen.name), setting to 0.0" maxlog = 1
        shutdown_cost = 0.0
    end

    op_cost = PSY.MultiStartCost(var_cost, no_load_cost, fixed, startup_cost, shutdown_cost)

    component = PSY.ThermalMultiStart(;
        name = PSY.get_name(thermal_gen),
        available = PSY.get_available(thermal_gen),
        status = PSY.get_status(thermal_gen),
        bus = PSY.get_bus(thermal_gen),
        active_power = PSY.get_active_power(thermal_gen),
        reactive_power = PSY.get_reactive_power(thermal_gen),
        rating = PSY.get_rating(thermal_gen),
        prime_mover = PSY.get_prime_mover(thermal_gen),
        fuel = PSY.get_fuel(thermal_gen),
        active_power_limits = PSY.get_active_power_limits(thermal_gen),
        reactive_power_limits = PSY.get_reactive_power_limits(thermal_gen),
        ramp_limits = PSY.get_ramp_limits(thermal_gen),
        power_trajectory = power_trajectory,
        time_limits = PSY.get_time_limits(thermal_gen),
        start_time_limits = startup_timelimits,
        start_types = start_types,
        operation_cost = op_cost,
        base_power = PSY.get_base_power(thermal_gen),
        time_at_status = PSY.get_time_at_status(thermal_gen),
        must_run = gen.must_run,
    )

    if ((gen.fotr, gen.mttr) != (nothing, nothing))
        add_outage_info!(component, gen)
    end

    return component
end
##############################################
# PowerSystems2PRAS definition of make_hydro_generator()
##############################################
function PSY.make_hydro_generator(gen_type, data::PSY.PowerSystemTableData, gen, cost_colnames, bus, gen_storage,)
    @debug "Making HydroGen" _group = PSY.IS.LOG_GROUP_PARSING gen.name
    active_power_limits =
        (min = gen.active_power_limits_min, max = gen.active_power_limits_max)
    (reactive_power, reactive_power_limits) = PSY.make_reactive_params(gen)
    rating = PSY.calculate_rating(active_power_limits, reactive_power_limits)
    ramp_limits = PSY.make_ramplimits(gen)
    min_up_time = gen.min_up_time
    min_down_time = gen.min_down_time
    time_limits = PSY.make_timelimits(gen, :min_up_time, :min_down_time)
    base_power = gen.base_mva

    if gen_type == PSY.HydroEnergyReservoir || gen_type == PSY.HydroPumpedStorage
        if !haskey(data.category_to_df, PSY.InputCategory.STORAGE)
            throw(PSY.DataFormatError("Storage information must defined in storage.csv"))
        end

        head_dict, tail_dict = gen_storage
        if !haskey(head_dict, gen.name)
            throw(DataFormatError("Cannot find head storage for $(gen.csv) in storage.csv"))
        end
        storage = (head = head_dict[gen.name], tail = get(tail_dict, gen.name, nothing))

        var_cost, fixed, fuel_cost =
            PSY.calculate_variable_cost(data, gen, cost_colnames, base_power)
        operation_cost = PSY.TwoPartCost(var_cost, fixed)

        if gen_type == PSY.HydroEnergyReservoir
            @debug "Creating $(gen.name) as HydroEnergyReservoir" _group =
                PSY.IS.LOG_GROUP_PARSING

            hydro_gen = PSY.HydroEnergyReservoir(
                name = gen.name,
                available = gen.available,
                bus = bus,
                active_power = gen.active_power,
                reactive_power = reactive_power,
                prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
                rating = rating,
                active_power_limits = active_power_limits,
                reactive_power_limits = reactive_power_limits,
                ramp_limits = ramp_limits,
                time_limits = time_limits,
                operation_cost = operation_cost,
                base_power = base_power,
                storage_capacity = storage.head.storage_capacity,
                inflow = storage.head.input_active_power_limit_max,
                initial_storage = storage.head.energy_level,
            )

        elseif gen_type == PSY.HydroPumpedStorage
            @debug "Creating $(gen.name) as HydroPumpedStorage" _group =
                PSY.IS.LOG_GROUP_PARSING

            pump_active_power_limits = (
                min = gen.pump_active_power_limits_min,
                max = gen.pump_active_power_limits_max,
            )
            (pump_reactive_power, pump_reactive_power_limits) = PSY.make_reactive_params(
                gen,
                powerfield = :pump_reactive_power,
                minfield = :pump_reactive_power_limits_min,
                maxfield = :pump_reactive_power_limits_max,
            )
            pump_rating =
            PSY.calculate_rating(pump_active_power_limits, pump_reactive_power_limits)
            pump_ramp_limits = PSY.make_ramplimits(
                gen;
                ramplimcol = :pump_ramp_limits,
                rampupcol = :pump_ramp_up,
                rampdncol = :pump_ramp_down,
            )
            pump_time_limits = PSY.make_timelimits(gen, :pump_min_up_time, :pump_min_down_time)
            hydro_gen = PSY.HydroPumpedStorage(
                name = gen.name,
                available = gen.available,
                bus = bus,
                active_power = gen.active_power,
                reactive_power = reactive_power,
                rating = rating,
                base_power = base_power,
                prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
                active_power_limits = active_power_limits,
                reactive_power_limits = reactive_power_limits,
                ramp_limits = ramp_limits,
                time_limits = time_limits,
                rating_pump = pump_rating,
                active_power_limits_pump = pump_active_power_limits,
                reactive_power_limits_pump = pump_reactive_power_limits,
                ramp_limits_pump = pump_ramp_limits,
                time_limits_pump = pump_time_limits,
                storage_capacity = (
                    up = storage.head.storage_capacity,
                    down = storage.head.storage_capacity,
                ),
                inflow = storage.head.input_active_power_limit_max,
                outflow = storage.tail.input_active_power_limit_max,
                initial_storage = (
                    up = storage.head.energy_level,
                    down = storage.tail.energy_level,
                ),
                storage_target = (
                    up = storage.head.storage_target,
                    down = storage.tail.storage_target,
                ),
                operation_cost = operation_cost,
                pump_efficiency = storage.tail.efficiency,
            )
        end
    elseif gen_type == PSY.HydroDispatch
        @debug "Creating $(gen.name) as HydroDispatch" _group = PSY.IS.LOG_GROUP_PARSING
        hydro_gen = PSY.HydroDispatch(
            name = gen.name,
            available = gen.available,
            bus = bus,
            active_power = gen.active_power,
            reactive_power = reactive_power,
            rating = rating,
            prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
            active_power_limits = active_power_limits,
            reactive_power_limits = reactive_power_limits,
            ramp_limits = ramp_limits,
            time_limits = time_limits,
            base_power = base_power,
        )
    else
        error("Tabular data parser does not currently support $gen_type creation")
    end

    if ((gen.fotr, gen.mttr) != (nothing, nothing))
        add_outage_info!(hydro_gen, gen)
    end

    return hydro_gen
end
##############################################
# PowerSystems2PRAS definition of make_renewable_generator()
##############################################
function PSY.make_renewable_generator(
    gen_type,
    data::PSY.PowerSystemTableData,
    gen,
    cost_colnames,
    bus,
)
@debug "Making RenewableGen" _group = PSY.IS.LOG_GROUP_PARSING gen.name
    generator = nothing
    active_power_limits =
        (min = gen.active_power_limits_min, max = gen.active_power_limits_max)
    (reactive_power, reactive_power_limits) = PSY.make_reactive_params(gen)
    rating = PSY.calculate_rating(active_power_limits, reactive_power_limits)
    base_power = gen.base_mva
    var_cost, fixed, fuel_cost =
        PSY.calculate_variable_cost(data, gen, cost_colnames, base_power)
    operation_cost = PSY.TwoPartCost(var_cost, fixed)

    if gen_type == PSY.RenewableDispatch
        @debug "Creating $(gen.name) as RenewableDispatch" _group = PSY.IS.LOG_GROUP_PARSING
        generator = PSY.RenewableDispatch(
            name = gen.name,
            available = gen.available,
            bus = bus,
            active_power = gen.active_power,
            reactive_power = reactive_power,
            rating = rating,
            prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
            reactive_power_limits = reactive_power_limits,
            power_factor = gen.power_factor,
            operation_cost = operation_cost,
            base_power = base_power,
        )
    elseif gen_type == PSY.RenewableFix
        @debug "Creating $(gen.name) as RenewableFix" _group = PSY.IS.LOG_GROUP_PARSING
        generator = PSY.RenewableFix(
            name = gen.name,
            available = gen.available,
            bus = bus,
            active_power = gen.active_power,
            reactive_power = reactive_power,
            rating = rating,
            prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
            power_factor = gen.power_factor,
            base_power = base_power,
        )
    else
        error("Unsupported type $gen_type")
    end

    if ((gen.fotr, gen.mttr) != (nothing, nothing))
        add_outage_info!(generator, gen)
    end

    return generator
end
##############################################
# PowerSystems2PRAS definition of make_storage()
##############################################
function PSY.make_storage(data::PSY.PowerSystemTableData, gen, bus, storage)
    @debug "Making Storage" _group = PSY.IS.LOG_GROUP_PARSING storage.name
    state_of_charge_limits =
        (min = storage.min_storage_capacity, max = storage.storage_capacity)
    input_active_power_limits = (
        min = storage.input_active_power_limit_min,
        max = storage.input_active_power_limit_max,
    )
    output_active_power_limits = (
        min = storage.output_active_power_limit_min,
        max = isnothing(storage.output_active_power_limit_max) ?
              gen.active_power_limits_max : storage.output_active_power_limit_max,
    )
    efficiency = (in = storage.input_efficiency, out = storage.output_efficiency)
    (reactive_power, reactive_power_limits) = PSY.make_reactive_params(storage)

    battery = PSY.GenericBattery(
        name = gen.name,
        available = storage.available,
        bus = bus,
        prime_mover = PSY.parse_enum_mapping(PSY.PrimeMovers, gen.unit_type),
        initial_energy = storage.energy_level,
        state_of_charge_limits = state_of_charge_limits,
        rating = storage.rating,
        active_power = storage.active_power,
        input_active_power_limits = input_active_power_limits,
        output_active_power_limits = output_active_power_limits,
        efficiency = efficiency,
        reactive_power = reactive_power,
        reactive_power_limits = reactive_power_limits,
        base_power = storage.base_power,
    )

    if ((gen.fotr, gen.mttr) != (nothing, nothing))
        add_outage_info!(battery, gen)
    end

    return battery
end
