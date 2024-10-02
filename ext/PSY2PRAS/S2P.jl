#######################################################
# Surya
# NREL
# January 2021
# SIIP --> PRAS Linkage Module
#######################################################

function PRAS.assess(
    system::PSY.System,
    method::PRAS.SequentialMonteCarlo,
    resultspecs
)
    pras_sys = make_pras_system(system,aggregation="Area")

    return PRAS.assess(pras_sys,method,resultspecs)
end


#######################################################
# Outage Information CSV
#######################################################
const OUTAGE_INFO_FILE =
    joinpath(@__DIR__, "descriptors", "outage-rates-ERCOT-modified.csv") 

df_outage = DataFrames.DataFrame(CSV.File(OUTAGE_INFO_FILE));

# PSY-3.X HVDC Types
const HVDCLineTypes = Union{PSY.TwoTerminalHVDCLine, PSY.TwoTerminalVSCDCLine}
const TransformerTypes = [PSY.TapTransformer, PSY.Transformer2W,PSY.PhaseShiftingTransformer]
#######################################################
# Structs to parse and store the outage information
#######################################################
struct outage_data
    prime_mover::String
    thermal_fuel::String
    capacity::Int64
    FOR::Float64
    MTTR::Int64

    outage_data(prime_mover  = "PrimeMovers.Default", thermal_fuel ="ThermalFuels.Default", capacity = 100, FOR=0.5,MTTR = 50) =new(prime_mover,thermal_fuel,capacity,FOR,MTTR)
end 

outage_values =[]
for row in eachrow(df_outage)
    push!(outage_values, outage_data(row.PrimeMovers,row.ThermalFuels,row.NameplateLimit_MW,(row.FOR/100),row.MTTR))
end

##############################################
# Converting FOR and MTTR to λ and μ
##############################################
function outage_to_rate(for_gen::Float64, mttr::Int64)
    if (for_gen > 1.0)
        for_gen = for_gen/100
    end

    if (for_gen == 1.0)
        λ = 1.0
        μ = 0.0
    else
        if ~(mttr == 0)
            μ = 1 / mttr
        else
            μ = 1.0
        end
        λ = (μ * for_gen) / (1 - for_gen)
    end

    return (λ = λ, μ = μ)
end

#######################################################
# Aux Functions
# General
#######################################################
#######################################################
# Function to get available components in AggregationTopology
#######################################################
function get_available_components_in_aggregation_topology(type::Type{<:PSY.StaticInjection}, sys::PSY.System, region::PSY.AggregationTopology)
    avail_comps =  filter(x ->(PSY.get_available(x)),collect(PSY.get_components_in_aggregation_topology(type, sys, region)))
    return avail_comps
end

#######################################################
# Aux Functions
# Generators
#######################################################
#######################################################
# Functions to get generator category
#######################################################
function get_generator_category(gen::GEN) where {GEN <: PSY.RenewableGen}
    return string(PSY.get_prime_mover_type(gen))
end

function get_generator_category(gen::GEN) where {GEN <: PSY.ThermalGen}
    return string(PSY.get_fuel(gen))
end

function get_generator_category(gen::GEN) where {GEN <: PSY.HydroGen}
    return "Hydro"
end

function get_generator_category(stor::GEN) where {GEN <: PSY.Storage}
    if (occursin("Distributed",PSY.get_name(stor)))
        return "Distributed_Storage"
    elseif (occursin("Battery",PSY.get_name(stor)))
        return "Battery_Storage"
    else
        return "Battery"
    end
end

function get_generator_category(stor::GEN) where {GEN <: PSY.HybridSystem}
    return "Hybrid-System"
end
#######################################################
# Aux Functions
# Lines
#######################################################
#######################################################
# Line Rating
#######################################################
function line_rating(line::Union{PSY.Line,PSY.MonitoredLine})
    rate = PSY.get_rate(line);
    return(forward_capacity = abs(rate) , backward_capacity = abs(rate))
end

function line_rating(line::PSY.TwoTerminalHVDCLine)
    forward_capacity = getfield(PSY.get_active_power_limits_from(line), :max)
    backward_capacity = getfield(PSY.get_active_power_limits_to(line), :max)
    return(forward_capacity = abs(forward_capacity), backward_capacity = abs(backward_capacity))
end

function line_rating(line::DCLine) where {DCLine<:HVDCLineTypes}
    error("line_rating isn't defined for $(typeof(line))")
end
#######################################################
# Get sorted (reg_from,reg_to) of inter-regional lines
#######################################################
function get_sorted_region_tuples(lines::Vector{PSY.Branch}, region_names::Vector{String})
    region_idxs = Dict(name => idx for (idx, name) in enumerate(region_names))

    line_from_to_reg_idxs = similar(lines, Tuple{Int, Int})
    print(region_idxs)
    for (l, line) in enumerate(lines)
        from_name = PSY.get_name(PSY.get_area(PSY.get_from_bus(line)))
        to_name = PSY.get_name(PSY.get_area(PSY.get_to_bus(line)))

        from_idx = region_idxs[from_name]
        to_idx = region_idxs[to_name]

        line_from_to_reg_idxs[l] =
            from_idx < to_idx ? (from_idx, to_idx) : (to_idx, from_idx)
    end

    return line_from_to_reg_idxs
end

#######################################################
# Get sorted lines and other indices necessary for PRAS
#######################################################
function get_sorted_lines(lines::Vector{PSY.Branch}, region_names::Vector{String})
    line_from_to_reg_idxs = get_sorted_region_tuples(lines, region_names)
    line_ordering = sortperm(line_from_to_reg_idxs)

    sorted_lines = lines[line_ordering]
    sorted_from_to_reg_idxs = line_from_to_reg_idxs[line_ordering]
    interface_reg_idxs = unique(sorted_from_to_reg_idxs)

    # Ref tells Julia to use interfaces as Vector, only broadcasting over
    # lines_sorted
    interface_line_idxs = searchsorted.(Ref(sorted_from_to_reg_idxs), interface_reg_idxs)

    return sorted_lines, interface_reg_idxs, interface_line_idxs
end

#######################################################
# Make PRAS Lines and Interfaces
#######################################################
function make_pras_interfaces(sorted_lines::Vector{PSY.Branch},interface_reg_idxs::Vector{Tuple{Int64, Int64}},
                              interface_line_idxs::Vector{UnitRange{Int64}},N::Int64)
    num_interfaces = length(interface_reg_idxs)
    interface_regions_from = first.(interface_reg_idxs)
    interface_regions_to = last.(interface_reg_idxs)
    num_lines = length(sorted_lines)

    # Lines
    line_names = PSY.get_name.(sorted_lines)
    line_cats = string.(typeof.(sorted_lines))

    line_forward_cap = Matrix{Int64}(undef, num_lines, N);
    line_backward_cap = Matrix{Int64}(undef, num_lines, N);
    line_λ = Matrix{Float64}(undef, num_lines, N); # Not currently available/ defined in PowerSystems
    line_μ = Matrix{Float64}(undef, num_lines, N); # Not currently available/ defined in PowerSystems

    for i in 1:num_lines
        line_forward_cap[i,:] = fill.(floor.(Int,getfield(line_rating(sorted_lines[i]),:forward_capacity)),1,N);
        line_backward_cap[i,:] = fill.(floor.(Int,getfield(line_rating(sorted_lines[i]),:backward_capacity)),1,N);

        ext = PSY.get_ext(sorted_lines[i])
        λ = 0.0;
        μ = 1.0;
        if ((haskey(ext,"outage_probability") && haskey(ext,"recovery_probability")))
            λ = ext["outage_probability"];
            μ = ext["recovery_probability"];
        else
            @warn "No outage information is available in ext of $(PSY.get_name(sorted_lines[i])). Using nominal outage and recovery probabilities for this line."
        end
    
        line_λ[i,:] = fill(λ,1,N); # Not currently available/ defined in PowerSystems # should change when we have this
        line_μ[i,:] = fill(μ,1,N); # Not currently available/ defined in PowerSystems
    end

    new_lines = PRAS.Lines{N, 1, PRAS.Hour, PRAS.MW}(
        line_names,
        line_cats,
        line_forward_cap,
        line_backward_cap,
        line_λ,
        line_μ,
    )

    interface_forward_capacity_array = Matrix{Int64}(undef, num_interfaces, N)
    interface_backward_capacity_array = Matrix{Int64}(undef, num_interfaces, N)

     for i in 1:num_interfaces
        interface_forward_capacity_array[i,:] =  sum(line_forward_cap[interface_line_idxs[i],:],dims=1)
        interface_backward_capacity_array[i,:] =  sum(line_backward_cap[interface_line_idxs[i],:],dims=1)
    end

    new_interfaces = PRAS.Interfaces{N, PRAS.MW}(
        interface_regions_from,
        interface_regions_to,
        interface_forward_capacity_array,
        interface_backward_capacity_array,
    )

    return new_lines, new_interfaces
end

#######################################################
# Main Function to make the PRAS System
#######################################################
function make_pras_system(sys::PSY.System;
                          system_model::Union{Nothing, String} = nothing, aggregation::Union{Nothing, String} = nothing,
                          period_of_interest::Union{Nothing, UnitRange} = nothing,outage_flag=true,lump_pv_wind_gens=false,availability_flag=true, 
                          outage_csv_location::Union{Nothing, String} = nothing, pras_sys_exp_loc::Union{Nothing, String} = nothing)
    """
    make_pras_system(psy_sys,system_model)

    PSY System and System Model ("Single-Node","Zonal") are taken as arguments 
    and a PRAS SystemModel is returned.
    
    ...
    # Arguments
    - `psy_sys::PSY.System`: PSY System
    - `system_model::String`: "Copper Plate" (or) "Zonal"
    - `aggregation::String`: "Area" (or) "LoadZone" {Optional} 
    - `num_time_steps::UnitRange`: Number of timesteps of PRAS SystemModel {Opt     ional} 
    ...

    # Examples
    ```julia-repl
    julia> make_pras_system(psy_sys,system_model,period_of_interest)
    PRAS SystemModel
    ```
    """
    PSY.set_units_base_system!(sys, PSY.IS.UnitSystem.NATURAL_UNITS); # PRAS needs PSY System to be in NATURAL_UNITS
    #######################################################
    # Double counting of HybridSystem subcomponents
    #######################################################
    dup_uuids =[];
    h_s_comps = availability_flag ? PSY.get_components(PSY.get_available, PSY.HybridSystem, sys) : PSY.get_components(PSY.HybridSystem, sys)
    for h_s in h_s_comps
        h_s_subcomps = PSY._get_components(h_s)
        for subcomp in h_s_subcomps
            push!(dup_uuids,PSY.IS.get_uuid(subcomp))
        end
    end
    #######################################################
    # kwargs Handling
    #######################################################
    if (aggregation === nothing)
        aggregation_topology = "Area";
    else
        if(PSY.string_compare(aggregation, "Area"))
            aggregation = "Area"
        elseif (PSY.string_compare(aggregation, "LoadZone"))
            aggregation = "LoadZone"
        else
            error("Unidentified aggregation passed.")
        end
    end

    aggregation_topology =
    if (aggregation=="Area")
        PSY.Area
    else
        PSY.LoadZone
    end
    #######################################################
    # Function to handle PSY timestamps
    #######################################################
    function get_period_of_interest(ts::TS) where {TS <: PSY.StaticTimeSeries}
        return range(1,length = length(ts.data))
    end

    function get_period_of_interest(ts::TS) where {TS <: PSY.AbstractDeterministic}
        return range(1,length = length(ts.data)*interval_len)
    end

    function get_len_ts_data(ts::TS) where {TS <: PSY.StaticTimeSeries}
        return length(ts.data)
    end

    function get_len_ts_data(ts::TS) where {TS <: PSY.AbstractDeterministic}
        return length(ts.data)*interval_len
    end

    all_ts = PSY.get_time_series_multiple(sys);
    first_ts_temp = first(all_ts);
    sys_ts_types = unique(typeof.(all_ts));
    # Time series information
    sys_for_int_in_hour = round(Dates.Millisecond(PSY.get_forecast_interval(sys)), Dates.Hour);
    sys_res_in_hour = round(Dates.Millisecond(PSY.get_time_series_resolution(sys)), Dates.Hour);
    interval_len = Int(sys_for_int_in_hour.value/sys_res_in_hour.value);
    sys_horizon =  PSY.get_forecast_horizon(sys);

    if (period_of_interest === nothing)
        period_of_interest = get_period_of_interest(first_ts_temp)
    else
        if (PSY.DeterministicSingleTimeSeries in sys_ts_types)
            if !(period_of_interest.start %  interval_len ==1 && period_of_interest.stop %  interval_len == 0)
                error("This PSY System has Determinstic time series data with interval length of $(interval_len). The period of interest should therefore be multiples of $(interval_len) to account for forecast windows.")
            end
        end
    end

    N = length(period_of_interest);
    len_ts_data = get_len_ts_data(first_ts_temp)

    if ((N+(period_of_interest.start-1))> len_ts_data)
        error("Cannot make a PRAS System with $(N) timesteps with a PSY System with only $(length(first_ts_temp.data) - (period_of_interest.start-1)) timesteps of time series data")
    end
    if (period_of_interest.start >  len_ts_data || period_of_interest.stop >  len_ts_data)
        error("Please check the system period of interest selected")
    end

    #=
    # Check if all time series data has a scaling_factor_multiplier
    if(!all(.!isnothing.(getfield.(all_ts,:scaling_factor_multiplier))))
        #error("Not all time series associated with components have scaling factor multipliers. This might lead to discrepancies in time series data in the PRAS System.")
        @warn "Not all time series associated with components have scaling factor multipliers. This might lead to discrepancies in time series data in the PRAS System."
    end
    =#
    # if outage_csv_location is passed, perform some data checks
    outage_ts_flag = false
    if (outage_csv_location !== nothing)
        outage_ts_data,outage_ts_flag = try
            @info "Parsing the CSV with outage time series data ..."
            DataFrames.DataFrame(CSV.File(outage_csv_location)), true
        catch ex
            error("Couldn't parse the CSV with outage data at $(outage_csv_location).") 
            throw(ex)
        end
    end
    if (outage_ts_flag)
        if (N>DataFrames.nrow(outage_ts_data))
            @warn "Outage time series data is not available for all System timestamps in the CSV."
        end
    end

    det_ts_period_of_interest = 
    if (~isempty(intersect(sys_ts_types, IU.subtypes(PSY.AbstractDeterministic))))
        strt = 
        if (round(Int,period_of_interest.start/interval_len) ==0)
            1
        else
            round(Int,period_of_interest.start/interval_len)
        end
        stp = round(Int,period_of_interest.stop/interval_len)

        range(strt,length = (stp-strt)+1)
        
    end
    #######################################################
    # Common function to handle getting time series values
    #######################################################
    function get_forecast_values(ts::TS) where {TS <: PSY.AbstractDeterministic}
        if (typeof(ts) == PSY.DeterministicSingleTimeSeries)
            forecast_vals = get_forecast_values(ts.single_time_series)
        else
            forecast_vals = []
            for it in collect(keys(PSY.get_data(ts)))[det_ts_period_of_interest]
                append!(forecast_vals,collect(values(PSY.get_window(ts, it; len=interval_len))))
            end
        end
        return forecast_vals
    end

    function get_forecast_values(ts::TS) where {TS <: PSY.StaticTimeSeries}
        forecast_vals = values(PSY.get_data(ts))[period_of_interest]
        return forecast_vals
    end
    #######################################################
    # Functions to handle components with no time series
    # usually the ones who's availability is set to false
    #######################################################
    function get_first_ts(ts::TS) where {TS <: Channel{Any}}
        if isempty(ts)
            return nothing
        else
            return first(ts)
        end
    end
    function get_forecast_values(ts::Nothing)
        return zeros(length(period_of_interest))
    end
    #######################################################
    # PRAS timestamps
    # Need this to select timeseries values of interest
    #######################################################
    start_datetime = PSY.IS.get_initial_timestamp(first_ts_temp);
    start_datetime = start_datetime + Dates.Hour((period_of_interest.start-1)*sys_res_in_hour);
    start_datetime_tz = TimeZones.ZonedDateTime(start_datetime,TimeZones.tz"UTC");
    finish_datetime_tz = start_datetime_tz +  Dates.Hour((N-1)*sys_res_in_hour);
    my_timestamps = StepRange(start_datetime_tz, Dates.Hour(sys_res_in_hour), finish_datetime_tz);

    @info "The first timestamp of PRAS System being built is : $(start_datetime_tz) and last timestamp is : $(finish_datetime_tz) "

    LoadType = 
    if (length(PSY.get_components(PSY.PowerLoad,sys)) > 0)
        PSY.PowerLoad
    else
        PSY.StandardLoad
    end
    #######################################################
     # PRAS Regions - Areas in SIIP
    #######################################################
    @info "Processing Regions in PSY System... "
    regions = collect(PSY.get_components(aggregation_topology, sys));
    if (length(regions)!=0)
        @info "The PSY System has $(length(regions)) regions based on PSY AggregationTopology : $(aggregation_topology)."
    else
        error("No regions in the PSY System. Cannot proceed with the process of making a PRAS SystemModel.")
    end 

    region_names = PSY.get_name.(regions);
    num_regions = length(region_names);

    region_load = Array{Int64,2}(undef,num_regions,N);
   
    for (idx,region) in enumerate(regions)
        reg_load_comps = availability_flag ? get_available_components_in_aggregation_topology(LoadType, sys, region) :
                                             PSY.get_components_in_aggregation_topology(LoadType, sys, region)
        if (length(reg_load_comps) > 0)
            region_load[idx,:]=floor.(Int,sum(get_forecast_values.(get_first_ts.(PSY.get_time_series_multiple.(reg_load_comps, name = "max_active_power")))
                               .*PSY.get_max_active_power.(reg_load_comps))); # Any issues with using the first of time_series_multiple?
        else
            region_load[idx,:] = zeros(Int64,N)
        end
    end

    new_regions = PRAS.Regions{N,PRAS.MW}(region_names, region_load);

    #######################################################
    # kwargs Handling
    #######################################################
    if (system_model === nothing)
        if (num_regions>1)
            system_model = "Zonal"
        else
            system_model = "Copper Plate"
        end
    else
        if(PSY.string_compare(system_model, "Copper Plate"))
            system_model = "Copper Plate"
        elseif (PSY.string_compare(system_model, "Zonal"))
            system_model = "Zonal"
        else
            error("Unidentified system model passed.")
        end
    end
    #######################################################
    # Generator Region Indices
    #######################################################
    gens=Array{PSY.Generator}[];
    start_id = Array{Int64}(undef,num_regions); 
    region_gen_idxs = Array{UnitRange{Int64},1}(undef,num_regions); 
    reg_wind_gens_DA = []
    reg_pv_gens_DA = []

    if (lump_pv_wind_gens)
        for (idx,region) in enumerate(regions)
            reg_ren_comps = availability_flag ? get_available_components_in_aggregation_topology(PSY.RenewableGen, sys, region) :
                                                 PSY.get_components_in_aggregation_topology(PSY.RenewableGen, sys, region)
            wind_gs_DA= [g for g in reg_ren_comps if (PSY.get_prime_mover_type(g) == PSY.PrimeMovers.WT)] 
            pv_gs_DA= [g for g in reg_ren_comps if (PSY.get_prime_mover_type(g) == PSY.PrimeMovers.PVe)] 
            reg_gen_comps = availability_flag ? get_available_components_in_aggregation_topology(PSY.Generator, sys, region) :
                                                PSY.get_components_in_aggregation_topology(PSY.Generator, sys, region)
            gs= [g for g in reg_gen_comps if (typeof(g) != PSY.HydroEnergyReservoir && PSY.get_max_active_power(g)!=0 && 
                                              PSY.IS.get_uuid(g) ∉ union(dup_uuids,PSY.IS.get_uuid.(wind_gs_DA),PSY.IS.get_uuid.(pv_gs_DA)))] 
            push!(gens,gs)
            push!(reg_wind_gens_DA,wind_gs_DA)
            push!(reg_pv_gens_DA,pv_gs_DA)

            if (idx==1)
                start_id[idx] = 1
            else 
                if (length(reg_wind_gens_DA[idx-1]) > 0 && length(reg_pv_gens_DA[idx-1]) > 0)
                    start_id[idx] =start_id[idx-1]+length(gens[idx-1])+2
                elseif (length(reg_wind_gens_DA[idx-1]) > 0 || length(reg_pv_gens_DA[idx-1]) > 0)
                    start_id[idx] =start_id[idx-1]+length(gens[idx-1])+1
                else
                    start_id[idx] =start_id[idx-1]+length(gens[idx-1])
                end
            end

            if (length(reg_wind_gens_DA[idx]) > 0 && length(reg_pv_gens_DA[idx]) > 0)
                region_gen_idxs[idx] = range(start_id[idx], length=length(gens[idx])+2)
            elseif (length(reg_wind_gens_DA[idx]) > 0 || length(reg_pv_gens_DA[idx]) > 0)
                region_gen_idxs[idx] = range(start_id[idx], length=length(gens[idx])+1)
            else
                region_gen_idxs[idx] = range(start_id[idx], length=length(gens[idx]))
            end
        end
    else
        for (idx,region) in enumerate(regions)
            reg_gen_comps = availability_flag ? get_available_components_in_aggregation_topology(PSY.Generator, sys, region) :
                                                PSY.get_components_in_aggregation_topology(PSY.Generator, sys, region)
            gs= [g for g in reg_gen_comps if (typeof(g) != PSY.HydroEnergyReservoir && PSY.get_max_active_power(g)!=0 && PSY.IS.get_uuid(g) ∉ dup_uuids)]
            push!(gens,gs)
            idx==1 ? start_id[idx] = 1 : start_id[idx] =start_id[idx-1]+length(gens[idx-1])
            region_gen_idxs[idx] = range(start_id[idx], length=length(gens[idx]))
        end
    end
    #######################################################
    # Storages Region Indices
    #######################################################
    stors=[];
    start_id = Array{Int64}(undef,num_regions);
    region_stor_idxs = Array{UnitRange{Int64},1}(undef,num_regions);

    for (idx,region) in enumerate(regions)
        #push!(stors,[s for s in PSY.get_components_in_aggregation_topology(PSY.Storage, sys, region)])
        reg_stor_comps = availability_flag ? get_available_components_in_aggregation_topology(PSY.Storage, sys, region) :
                                             PSY.get_components_in_aggregation_topology(PSY.Storage, sys, region)
        push!(stors,[s for s in reg_stor_comps if (PSY.IS.get_uuid(s) ∉ dup_uuids)])
        idx==1 ? start_id[idx] = 1 : start_id[idx] =start_id[idx-1]+length(stors[idx-1])
        region_stor_idxs[idx] = range(start_id[idx], length=length(stors[idx]))
    end
    #######################################################
    # GeneratorStorages Region Indices
    #######################################################
    gen_stors=[];
    start_id = Array{Int64}(undef,num_regions);
    region_genstor_idxs = Array{UnitRange{Int64},1}(undef,num_regions);

    for (idx,region) in enumerate(regions)
        reg_gen_stor_comps = availability_flag ? get_available_components_in_aggregation_topology(PSY.StaticInjection, sys, region) :
                                                 PSY.get_components_in_aggregation_topology(PSY.StaticInjection, sys, region)
        gs= [g for g in reg_gen_stor_comps if (typeof(g) == PSY.HydroEnergyReservoir || typeof(g)==PSY.HybridSystem)]
        push!(gen_stors,gs)
        idx==1 ? start_id[idx] = 1 : start_id[idx] =start_id[idx-1]+length(gen_stors[idx-1])
        region_genstor_idxs[idx] = range(start_id[idx], length=length(gen_stors[idx]))
    end
    #######################################################
    # PRAS Generators
    #######################################################
    @info "Processing Generators in PSY System... "
    
    # Lumping Wind and PV Generators per Region
    if (lump_pv_wind_gens)
        for i in 1: num_regions
            if (length(reg_wind_gens_DA[i])>0)
                # Wind
                temp_lumped_wind_gen = PSY.RenewableDispatch(nothing)
                PSY.set_name!(temp_lumped_wind_gen,"Lumped_Wind_"*region_names[i])
                PSY.set_prime_mover_type!(temp_lumped_wind_gen,PSY.PrimeMovers.WT)
                ext = PSY.get_ext(temp_lumped_wind_gen)
                ext["region_gens"] = reg_wind_gens_DA[i]
                ext["outage_probability"] = 0.0
                ext["recovery_probability"] = 1.0
                push!(gens[i],temp_lumped_wind_gen)
            end
            if (length(reg_pv_gens_DA[i])>0)
                # PV
                temp_lumped_pv_gen = PSY.RenewableDispatch(nothing)
                PSY.set_name!(temp_lumped_pv_gen,"Lumped_PV_"*region_names[i])
                PSY.set_prime_mover_type!(temp_lumped_pv_gen,PSY.PrimeMovers.PVe)
                ext = PSY.get_ext(temp_lumped_pv_gen)
                ext["region_gens"] = reg_pv_gens_DA[i]
                ext["outage_probability"] = 0.0
                ext["recovery_probability"] = 1.0
                push!(gens[i],temp_lumped_pv_gen)
            end
        end
    end

    gen=[];
    for i in 1: num_regions
        if (length(gens[i]) != 0)
            append!(gen,gens[i])
        end
    end
    
    if(length(gen) ==0)
        gen_names = String[];
    else
        gen_names = PSY.get_name.(gen);
    end

    gen_categories = get_generator_category.(gen);
    n_gen = length(gen_names);

    gen_cap_array = Matrix{Int64}(undef, n_gen, N);
    λ_gen = Matrix{Float64}(undef, n_gen, N);
    μ_gen = Matrix{Float64}(undef, n_gen, N);

    for (idx,g) in enumerate(gen)
        # Nominal outage and recovery rate
        (λ,μ) = (0.0,1.0)
        
        if (lump_pv_wind_gens && (PSY.get_prime_mover_type(g) == PSY.PrimeMovers.WT || PSY.get_prime_mover_type(g) == PSY.PrimeMovers.PVe))
            reg_gens_DA = PSY.get_ext(g)["region_gens"];
            gen_cap_array[idx,:] = round.(Int,sum(get_forecast_values.(get_first_ts.(PSY.get_time_series_multiple.(reg_gens_DA, name = "max_active_power")))
                                   .*PSY.get_max_active_power.(reg_gens_DA)));
        else
            if (PSY.has_time_series(g) && ("max_active_power" in PSY.get_name.(PSY.get_time_series_multiple(g))))
                gen_cap_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g, name = "max_active_power")))
                                       *PSY.get_max_active_power(g));
                if ~(all(gen_cap_array[idx,:] .>=0))
                    @warn "There are negative values in max active time series data for $(PSY.get_name(g)) of type $(gen_categories[idx]) is negative. Using zeros for time series data." 
                    gen_cap_array[idx,:] = zeros(Int,N);
                end
            else
                if (PSY.get_max_active_power(g) > 0)
                    gen_cap_array[idx,:] = fill.(floor.(Int,PSY.get_max_active_power(g)),1,N);
                else
                    @warn "Max active power for $(PSY.get_name(g)) of type $(gen_categories[idx]) is negative. Using zeros for time series data." 
                    gen_cap_array[idx,:] = zeros(Int,N); # to handle components with negative active power (usually UNAVAIALABLE)
                end
            end
        end

        if (outage_ts_flag)
            try
                @info "Using FOR time series data for $(PSY.get_name(g)) of type $(gen_categories[idx]). Assuming the mean time to recover (MTTR) is 24 hours to compute the λ and μ time series data ..."
                g_λ_μ_ts_data = outage_to_rate.(outage_ts_data[!,PSY.get_name(g)],fill(24,length(outage_ts_data[!,PSY.get_name(g)])))
                λ_gen[idx,:] = getfield.(g_λ_μ_ts_data,:λ)
                μ_gen[idx,:] = getfield.(g_λ_μ_ts_data,:μ) # This assumes a mean time to recover of 24 hours.
            catch ex
                @warn "FOR time series data for $(PSY.get_name(g)) of type $(gen_categories[idx]) is not available in the CSV. Using nominal outage and recovery probabilities for this generator." 
                λ_gen[idx,:] = fill.(λ,1,N); 
                μ_gen[idx,:] = fill.(μ,1,N);
            end
        else
            if (~outage_flag)
                if (isa(g, PSY.ThermalGen))
                    p_m = string(PSY.get_prime_mover_type(g))
                    fl = string(PSY.get_fuel(g))

                    p_m_idx = findall(x -> x == p_m, getfield.(outage_values,:prime_mover))
                    fl_idx =  findall(x -> x == fl, getfield.(outage_values[p_m_idx],:thermal_fuel))
                    
                    if (length(fl_idx) ==0)
                        fl_idx =  findall(x -> x == "NA", getfield.(outage_values[p_m_idx],:thermal_fuel))
                    end

                    temp_range = p_m_idx[fl_idx]

                    temp_cap = floor(Int,PSY.get_max_active_power(g))

                    if (length(temp_range)>1)
                        gen_idx = temp_range[1]
                        for (x,y) in zip(temp_range,getfield.(outage_values[temp_range],:capacity))
                            temp=0
                            if (temp<temp_cap<y)
                                gen_idx = x
                                break
                            else
                                temp = y
                            end
                        end
                        f_or = getfield(outage_values[gen_idx],:FOR)
                        mttr_hr = getfield(outage_values[gen_idx],:MTTR)

                        (λ,μ) = outage_to_rate(f_or,mttr_hr)

                    elseif (length(temp_range)==1)
                        gen_idx = temp_range[1]
                        
                        f_or = getfield(outage_values[gen_idx],:FOR)
                        mttr_hr = getfield(outage_values[gen_idx],:MTTR)

                        (λ,μ) = outage_to_rate(f_or,mttr_hr)
                    else
                        @warn "No outage information is available for $(PSY.get_name(g)) with a $(p_m) prime mover and $(fl) fuel type. Using nominal outage and recovery probabilities for this generator."
                        #λ = 0.0;
                        #μ = 1.0;
                    end

                elseif (isa(g, PSY.HydroGen))
                    p_m = string(PSY.get_prime_mover_type(g))
                    p_m_idx = findall(x -> x == p_m, getfield.(outage_values,:prime_mover))

                    temp_cap = floor(Int,PSY.get_max_active_power(g))
                    
                    if (length(p_m_idx)>1)
                        for (x,y) in zip(p_m_idx,getfield.(outage_values[p_m_idx],:capacity))
                            temp=0
                            if (temp<temp_cap<y)
                                gen_idx = x

                                f_or = getfield(outage_values[gen_idx],:FOR)
                                mttr_hr = getfield(outage_values[gen_idx],:MTTR)

                                (λ,μ) = outage_to_rate(f_or,mttr_hr)
                                break
                            else
                                temp = y
                            end
                        end
                    end
                else
                    @warn "No outage information is available for $(PSY.get_name(g)) of type $(gen_categories[idx]). Using nominal outage and recovery probabilities for this generator."
                    #λ = 0.0;
                    #μ = 1.0;

                end

            else
                ext = PSY.get_ext(g)
                if (!(haskey(ext,"outage_probability") && haskey(ext,"recovery_probability")))
                    @warn "No outage information is available in ext field of $(PSY.get_name(g)) of type $(gen_categories[idx]). Using nominal outage and recovery probabilities for this generator."
                    #λ = 0.0;
                    #μ = 1.0;
                else
                    λ = ext["outage_probability"];
                    μ = ext["recovery_probability"];
                end
            end
            λ_gen[idx,:] = fill.(λ,1,N); 
            μ_gen[idx,:] = fill.(μ,1,N); 
        end
    end

    new_generators = PRAS.Generators{N,1,PRAS.Hour,PRAS.MW}(gen_names, get_generator_category.(gen), gen_cap_array , λ_gen ,μ_gen);
        
    #######################################################
    # PRAS Storages
    # **TODO Future : time series for storage devices
    #######################################################
    @info "Processing Storages in PSY System... "

    stor=[];
    for i in 1: num_regions
        if (length(stors[i]) != 0)
            append!(stor,stors[i])
        end
    end

    if(length(stor) ==0)
        stor_names=String[];
    else
        stor_names = PSY.get_name.(stor);
    end

    stor_categories = get_generator_category.(stor);

    n_stor = length(stor_names);

    stor_charge_cap_array = Matrix{Int64}(undef, n_stor, N);
    stor_discharge_cap_array = Matrix{Int64}(undef, n_stor, N);
    stor_energy_cap_array = Matrix{Int64}(undef, n_stor, N);
    stor_chrg_eff_array = Matrix{Float64}(undef, n_stor, N);
    stor_dischrg_eff_array  = Matrix{Float64}(undef, n_stor, N);
    λ_stor = Matrix{Float64}(undef, n_stor, N);   
    μ_stor = Matrix{Float64}(undef, n_stor, N);

    for (idx,s) in enumerate(stor)
        stor_charge_cap_array[idx,:] = fill(floor(Int,getfield(PSY.get_input_active_power_limits(s), :max)),1,N);
        stor_discharge_cap_array[idx,:] = fill(floor(Int,getfield(PSY.get_output_active_power_limits(s), :max)),1,N);
        stor_energy_cap_array[idx,:] = fill(floor(Int,getfield(PSY.get_state_of_charge_limits(s),:max)),1,N);
        stor_chrg_eff_array[idx,:] = fill(getfield(PSY.get_efficiency(s), :in),1,N);
        stor_dischrg_eff_array[idx,:]  = fill.(getfield(PSY.get_efficiency(s), :out),1,N);

        if (~outage_flag)
            @warn "No outage information is available for $(PSY.get_name(s)) of type $(stor_categories[idx]). Using nominal outage and recovery probabilities for this generator."
            λ = 0.0;
            μ = 1.0;
        else
            ext = PSY.get_ext(s)
            if (!(haskey(ext,"outage_probability") && haskey(ext,"recovery_probability")))
                @warn "No outage information is available in ext field of $(PSY.get_name(s)) of type $(stor_categories[idx]). Using nominal outage and recovery probabilities for this generator."
                λ = 0.0;
                μ = 1.0;
            else
                λ = ext["outage_probability"];
                μ = ext["recovery_probability"];
            end
        end
        
        λ_stor[idx,:] = fill.(λ,1,N); 
        μ_stor[idx,:] = fill.(μ,1,N); 
    end
    
    stor_cryovr_eff = ones(n_stor,N);   # Not currently available/ defined in PowerSystems
    
    new_storage = PRAS.Storages{N,1,PRAS.Hour,PRAS.MW,PRAS.MWh}(stor_names,get_generator_category.(stor),
                                            stor_charge_cap_array,stor_discharge_cap_array,stor_energy_cap_array,
                                            stor_chrg_eff_array,stor_dischrg_eff_array, stor_cryovr_eff,
                                            λ_stor,μ_stor);

    #######################################################
    # PRAS Generator Storages
    # **TODO Consider all combinations of HybridSystem (Currently only works for DER+ESS)
    #######################################################
    @info "Processing GeneratorStorages in PSY System... "

    gen_stor=[];
    for i in 1: num_regions
        if (length(gen_stors[i]) != 0)
            append!(gen_stor,gen_stors[i])
        end
    end
    
    if(length(gen_stor) == 0)
        gen_stor_names=String[];
    else
        gen_stor_names = PSY.get_name.(gen_stor);
    end

    gen_stor_categories = string.(typeof.(gen_stor)); 
    
    n_genstors = length(gen_stor_names);

    gen_stor_charge_cap_array = Matrix{Int64}(undef, n_genstors, N);
    gen_stor_discharge_cap_array = Matrix{Int64}(undef, n_genstors, N);
    gen_stor_enrgy_cap_array = Matrix{Int64}(undef, n_genstors, N);
    gen_stor_inflow_array = Matrix{Int64}(undef, n_genstors, N);
    gen_stor_gridinj_cap_array = Matrix{Int64}(undef, n_genstors, N);

    λ_genstors = Matrix{Float64}(undef, n_genstors, N);   
    μ_genstors = Matrix{Float64}(undef, n_genstors, N);  

    for (idx,g_s) in enumerate(gen_stor)
        if(typeof(g_s) ==PSY.HydroEnergyReservoir)
            if (PSY.has_time_series(g_s))
                if ("inflow" in PSY.get_name.(PSY.get_time_series_multiple(g_s)))
                    gen_stor_charge_cap_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g_s, name = "inflow")))
                                                       *PSY.get_inflow(g_s));
                    gen_stor_discharge_cap_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g_s, name = "inflow")))
                                                          *PSY.get_inflow(g_s));
                    gen_stor_inflow_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g_s, name = "inflow")))
                                                   *PSY.get_inflow(g_s));
                else
                    gen_stor_charge_cap_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                    gen_stor_discharge_cap_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                    gen_stor_inflow_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                end
                if ("storage_capacity" in PSY.get_name.(PSY.get_time_series_multiple(g_s)))
                    gen_stor_enrgy_cap_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g_s, name = "storage_capacity")))
                                                      *PSY.get_storage_capacity(g_s));
                else
                    gen_stor_enrgy_cap_array[idx,:] = fill.(floor.(Int,PSY.get_storage_capacity(g_s)),1,N);
                end
                if ("max_active_power" in PSY.get_name.(PSY.get_time_series_multiple(g_s)))
                    gen_stor_gridinj_cap_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(g_s, name = "max_active_power")))
                                                        *PSY.get_max_active_power(g_s));
                else
                    gen_stor_gridinj_cap_array[idx,:] = fill.(floor.(Int,PSY.get_max_active_power(g_s)),1,N);
                end
            else
                gen_stor_charge_cap_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                gen_stor_discharge_cap_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                gen_stor_enrgy_cap_array[idx,:] = fill.(floor.(Int,PSY.get_storage_capacity(g_s)),1,N);
                gen_stor_inflow_array[idx,:] = fill.(floor.(Int,PSY.get_inflow(g_s)),1,N);
                gen_stor_gridinj_cap_array[idx,:] = fill.(floor.(Int,PSY.get_max_active_power(g_s)),1,N);
            end  
        else
            gen_stor_charge_cap_array[idx,:] = fill.(floor.(Int,getfield(PSY.get_input_active_power_limits(PSY.get_storage(g_s)), :max)),1,N);
            gen_stor_discharge_cap_array[idx,:] = fill.(floor.(Int,getfield(PSY.get_output_active_power_limits(PSY.get_storage(g_s)), :max)),1,N);
            gen_stor_enrgy_cap_array[idx,:] = fill.(floor.(Int,getfield(PSY.get_state_of_charge_limits(PSY.get_storage(g_s)), :max)),1,N); 
            gen_stor_gridinj_cap_array[idx,:] = fill.(floor.(Int,PSY.getfield(PSY.get_output_active_power_limits(g_s), :max)),1,N);
            
            if (PSY.has_time_series(PSY.get_renewable_unit(g_s)) && ("max_active_power" in PSY.get_name.(PSY.get_time_series_multiple(PSY.get_renewable_unit(g_s)))))
                gen_stor_inflow_array[idx,:] = floor.(Int,get_forecast_values(get_first_ts(PSY.get_time_series_multiple(PSY.get_renewable_unit(g_s), name = "max_active_power")))
                                               *PSY.get_max_active_power(PSY.get_renewable_unit(g_s))); 
            else
                gen_stor_inflow_array[idx,:] = fill.(floor.(Int,PSY.get_max_active_power(PSY.get_renewable_unit(g_s))),1,N); 
            end
        end
        
        if (~outage_flag)
            if (typeof(g_s) ==PSY.HydroEnergyReservoir)
                p_m = string(PSY.get_prime_mover_type(g_s))
                p_m_idx = findall(x -> x == p_m, getfield.(outage_values,:prime_mover))

                temp_cap = floor(Int,PSY.get_max_active_power(g_s))
                
                if (length(p_m_idx)>1)
                    for (x,y) in zip(p_m_idx,getfield.(outage_values[p_m_idx],:capacity))
                        temp=0
                        if (temp<temp_cap<y)
                            gen_idx = x

                            f_or = getfield(outage_values[gen_idx],:FOR)
                            mttr_hr = getfield(outage_values[gen_idx],:MTTR)

                            (λ,μ) = outage_to_rate(f_or,mttr_hr)
                            break
                        else
                            temp = y
                        end
                    end
                end
            else
                @warn "No outage information is available for $(PSY.get_name(g_s)) of type $(gen_stor_categories[idx]). Using nominal outage and recovery probabilities for this generator."
                λ = 0.0;
                μ = 1.0;
            end

        else
            ext = PSY.get_ext(g_s)
            if (!(haskey(ext,"outage_probability") && haskey(ext,"recovery_probability")))
                @warn "No outage information is available in ext field of $(PSY.get_name(g_s)) of type $(gen_stor_categories[idx]). Using nominal outage and recovery probabilities for this generator."
                λ = 0.0;
                μ = 1.0;
            else
                λ = ext["outage_probability"];
                μ = ext["recovery_probability"];
            end
        end
        
        λ_genstors[idx,:] = fill.(λ,1,N); 
        μ_genstors[idx,:] = fill.(μ,1,N);
    end
    
    gen_stor_gridwdr_cap_array = zeros(Int64,n_genstors, N); # Not currently available/ defined in PowerSystems
    gen_stor_charge_eff = ones(n_genstors,N);                # Not currently available/ defined in PowerSystems
    gen_stor_discharge_eff = ones(n_genstors,N);             # Not currently available/ defined in PowerSystems
    gen_stor_cryovr_eff = ones(n_genstors,N);                # Not currently available/ defined in PowerSystems

    
    new_gen_stors = PRAS.GeneratorStorages{N,1,PRAS.Hour,PRAS.MW,PRAS.MWh}(gen_stor_names,get_generator_category.(gen_stor),
                                                    gen_stor_charge_cap_array, gen_stor_discharge_cap_array, gen_stor_enrgy_cap_array,
                                                    gen_stor_charge_eff, gen_stor_discharge_eff, gen_stor_cryovr_eff,
                                                    gen_stor_inflow_array, gen_stor_gridwdr_cap_array, gen_stor_gridinj_cap_array,
                                                    λ_genstors, μ_genstors);

    #######################################################
    # PRAS SystemModel
    #######################################################
    if (system_model=="Zonal")
        #######################################################
        # PRAS Lines 
        #######################################################
        @info "Collecting all inter regional lines in PSY System..."

        lines = availability_flag ? 
        collect(PSY.get_components(x -> (typeof(x) ∉ TransformerTypes && PSY.get_available(x)), PSY.Branch, sys)) :
        collect(PSY.get_components(x -> (typeof(x) ∉ TransformerTypes), PSY.Branch, sys));

        #######################################################
        # Inter-Regional Line Processing
        #######################################################
        regional_lines = filter(x -> ~(x.arc.from.area.name == x.arc.to.area.name),lines);
        sorted_lines, interface_reg_idxs, interface_line_idxs = get_sorted_lines(regional_lines, region_names);
        new_lines, new_interfaces = make_pras_interfaces(sorted_lines, interface_reg_idxs, interface_line_idxs,N);
    
        pras_system = PRAS.SystemModel(new_regions, new_interfaces, new_generators, region_gen_idxs, new_storage, region_stor_idxs, new_gen_stors,
                          region_genstor_idxs, new_lines,interface_line_idxs,my_timestamps);

        @info "Successfully built a PRAS $(system_model) system of type $(typeof(pras_system))."

        if (pras_sys_exp_loc !== nothing)
            if ~(isprasfile(pras_sys_exp_loc))
                error("PRAS System export location should be a .pras file. $(pras_sys_exp_loc) is not a valid location.")
            else
                PRAS.savemodel(pras_system,pras_sys_exp_loc, string_length =100, verbose = true, compression_level = 9)
                @info "PRAS System exported can be found here : $(pras_sys_exp_loc)"
            end
        end
    
        return pras_system
    
    elseif (system_model =="Copper Plate")
        load_vector = vec(sum(region_load,dims=1));
        pras_system = PRAS.SystemModel(new_generators, new_storage, new_gen_stors, my_timestamps, load_vector);

        @info "Successfully built a PRAS $(system_model) system of type $(typeof(pras_system))."

        if (pras_sys_exp_loc !== nothing)
            if ~(isprasfile(pras_sys_exp_loc))
                error("PRAS System export location should be a .pras file. $(pras_sys_exp_loc) is not a valid location.")
            else
                PRAS.savemodel(pras_system,pras_sys_exp_loc, string_length =100, verbose = true, compression_level = 9)
                @info "PRAS System exported can be found here : $(pras_sys_exp_loc)"
            end
        end
    
        return pras_system
    else
        error("Unrecognized SystemModel; Please specify correctly if SystemModel is Single-Node or Zonal.")
    end
end

#######################################################
# Main Function to make the PRAS System
#######################################################
function make_pras_system(sys_location::String;
                          system_model::Union{Nothing, String} = nothing,aggregation::Union{Nothing, String} = nothing,
                          period_of_interest::Union{Nothing, UnitRange} = nothing,outage_flag=true,lump_pv_wind_gens=false,availability_flag=true, 
                          outage_csv_location::Union{Nothing, String} = nothing, pras_sys_exp_loc::Union{Nothing, String} = nothing)

    @info "Running checks on the System location provided ..."
    runchecks(sys_location)
    
    @info "The PowerSystems System is being de-serialized from the System JSON ..."
    sys = 
    try
        PSY.System(sys_location;time_series_read_only = true,runchecks = false);
    catch
        error("The PSY System could not be de-serialized using the location of JSON provided. Please check the location and make sure you have permission to access time_series_storage.h5")
    end

    make_pras_system(sys,system_model = system_model,aggregation = aggregation,period_of_interest = period_of_interest,
                     outage_flag = outage_flag,lump_pv_wind_gens = lump_pv_wind_gens,availability_flag = availability_flag, 
                     outage_csv_location = outage_csv_location, pras_sys_exp_loc = pras_sys_exp_loc) 
end

