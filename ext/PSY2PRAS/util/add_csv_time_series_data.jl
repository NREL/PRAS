#######################################################
# Surya
# NREL
# July 2021
# Generate PSY System from CSV Outage Profiles
# TODO: Handle Lumped Wind Plants
#######################################################
#  Handling CC units using cc_restrictions.json because 
# PSY has multiple CC units PRAS doesn't
#######################################################
const CC_RESTRICTIONS_UTIL_FILE =
joinpath(@__DIR__, "descriptors", "cc_restrictions.json") 
cc_restrictions_util_file = JSON.parsefile(CC_RESTRICTIONS_UTIL_FILE);
#######################################################
# Dict to handle different types of assets
#######################################################
csv_dict = Dict([("Generator.csv", PSY.Generator), ("Storage.csv","Storage.csv"),("GeneratorStorage.csv", PSY.StaticInjection),("Branch.csv",PSY.Branch)]);
#######################################################
# Generate Outage Profile for two stage SIIP Simulations
#######################################################
function add_csv_time_series!(sys_DA::PSY.System,sys_RT::PSY.System, outage_csv_location::String;days_of_interest::Union{Nothing, UnitRange} = nothing,
                              add_scenario::Union{Nothing, Int} = nothing)  
    #######################################################
    # kwarg handling
    #######################################################
    #  Handling CC units using cc_restrictions.json
    cc_restrictions_dict_DA = Dict()
    cc_restrictions_dict_RT = Dict()
    for key in keys(cc_restrictions_util_file)
        cc_gens_DA =[]
        cc_gens_RT =[] 
        for gen_name in cc_restrictions_util_file[key]
            push!(cc_gens_DA,PSY.get_component(PSY.Generator,sys_DA, gen_name))
            push!(cc_gens_RT,PSY.get_component(PSY.Generator,sys_RT, gen_name))
        end
            
        max_cap_idx_DA = argmax(PSY.get_max_active_power.(cc_gens_DA))
        max_cap_idx_RT = argmax(PSY.get_max_active_power.(cc_gens_RT))
        length(max_cap_idx_DA) >1 ? push!(cc_restrictions_dict_DA,PSY.get_name(cc_gens_DA[max_cap_idx_DA[1]]) =>cc_gens_DA) : push!(cc_restrictions_dict_DA,PSY.get_name(cc_gens_DA[max_cap_idx_DA]) =>cc_gens_DA)
        length(max_cap_idx_RT) >1 ? push!(cc_restrictions_dict_RT,PSY.get_name(cc_gens_RT[max_cap_idx_RT[1]]) =>cc_gens_RT) : push!(cc_restrictions_dict_RT,PSY.get_name(cc_gens_RT[max_cap_idx_RT]) =>cc_gens_RT)
    end

    @info "This script currently only adds availability time series to Generators in PSY System. This can be extended to handle Lines, Storage and Static Injections. "

    if (~isdir(outage_csv_location))
        error("Outage CSV location passed isn't a directory.")
    end

    (root, dirs, files) = first(walkdir(outage_csv_location))
    
    if (length(dirs) == 0)
        error("No scenario outage data available")
    end

    if (add_scenario === nothing)
        add_scenario = 1
        @warn  "The scenario to be used to get the asset availability time series data wasn't passed. Using availability time series data for scenario '1'."
    end

    dir_location = joinpath(root,string(add_scenario))
    csv_locations = readdir(dir_location)

    if (~("Generator.csv" in csv_locations))
        error("Generator Availability time series data not available for scenario $(add_scenario).")
    end
    #file_location = joinpath(dir_location,csv_locations[1])
    file_location = joinpath(dir_location,"Generator.csv")

    # Handling days of interest to generate time stamps
    first_ts_temp_DA = first(PSY.get_time_series_multiple(sys_DA));
    len_ts_data_DA = length(first_ts_temp_DA.data);

    if (days_of_interest === nothing)
        days_of_interest = range(1,length = len_ts_data_DA)
        @warn  "No days_of_interest passed. Using all the days for which data is available in PSY System. Please make sure these days of interest align with the availability data in the CSV file."
    end

     #Select Full Days to avoid more Processing
    if (~(1<=days_of_interest.start <= len_ts_data_DA) || ~(1<=days_of_interest.stop <= len_ts_data_DA))
        error("Please checked the passed days of interest (e.g 1:24,25:48,1:365 etc.)")
    end
    
    num_days = length(days_of_interest);
    period_of_interest = range(days_of_interest.start==1 ? 1 : (24*days_of_interest.start)+1,length=num_days*24)
    N = length(period_of_interest);
    #######################################################
    # Timestamps
    #######################################################
    start_datetime_DA = PSY.IS.get_initial_timestamp(first_ts_temp_DA);
    sys_DA_res_in_hour = PSY.get_time_series_resolution(sys_DA)
    start_datetime_DA = start_datetime_DA + Dates.Hour((period_of_interest.start-1)*sys_DA_res_in_hour);
    finish_datetime_DA = start_datetime_DA +  Dates.Hour((N-1)*sys_DA_res_in_hour);
    all_timestamps = StepRange(start_datetime_DA, sys_DA_res_in_hour, finish_datetime_DA);
    ######################################################
    # Reading the CSV Files
    #######################################################
    df_outage_profile = DataFrames.DataFrame(CSV.File(file_location));

    for asset_name in names(df_outage_profile)
        # Creating TimeSeries Data
        DA_data = Dict()
        RT_data = Dict()

        for (idx,timestamp) in enumerate(all_timestamps) #
            if (rem(idx,24) == 1)
                if (df_outage_profile[idx,asset_name] ==0)
                    push!(DA_data,timestamp => zeros(36))
                else
                    push!(DA_data,timestamp => ones(36))
                end
            end

            if (df_outage_profile[idx,asset_name] ==0)
                # If PRAS actual status is actually 0, just use 0 for RT, ReliablePSY can handle this transition
                push!(RT_data,timestamp => zeros(2))
            else
                # If PRAS actual status is actually 1 and DA says 1, use 1 for RT, if DA says 0, use O because ReliablePSY currently can't handle this
                if (rem(idx,24) == 0)
                    offset = 24
                else
                    offset = rem(idx,24)
                end

                if (df_outage_profile[(idx-offset+1),asset_name] ==1) # If PRAS Actual == 1 and DA ==1
                    push!(RT_data,timestamp => ones(2))
                else
                    push!(RT_data,timestamp => zeros(2)) # # If PRAS Actual == 1 and DA ==0 - Special case
                end
            end
        end

        DA_availability_forecast = PSY.Deterministic("outage", DA_data,sys_DA_res_in_hour)
        RT_availability_forecast = PSY.Deterministic("outage", RT_data,sys_DA_res_in_hour)
        
        # Adding TimeSeries Data to PSY System
        if (asset_name in keys(cc_restrictions_dict_DA))
            for component in cc_restrictions_dict_DA[asset_name]
                try
                    @info "Adding availability time series data for $(PSY.get_name(component)) Generator to DA System..."
                    PSY.add_time_series!(sys_DA,component, DA_availability_forecast)
                catch ex
                    @warn "Couldn't find a Generator with component name $(PSY.get_name(component)) in the DA PSY System. Proceeding without adding availability time series data for this component in the DA System."
                end
            end
        else
            try
                @info "Adding availability time series data for $(asset_name) Generator to DA System..."
                PSY.add_time_series!(sys_DA,PSY.get_component(PSY.Generator,sys_DA, asset_name), DA_availability_forecast)
            catch ex
                @warn "Couldn't find a Generator with component name $(asset_name) in the DA PSY System. Proceeding without adding availability time series data for this component in the DA System."
            end
        end
        
        if (asset_name in keys(cc_restrictions_dict_RT))
            for component in cc_restrictions_dict_RT[asset_name]
                try
                    @info "Adding availability time series data for $(PSY.get_name(component)) Generator to RT System..."
                    PSY.add_time_series!(sys_RT,component, RT_availability_forecast)
                catch ex
                    @warn "Couldn't find a Generator with component name $(PSY.get_name(component)) in the RT PSY System. Proceeding without adding availability time series data for this component in the RT System."
                end
            end

        else
            try
                @info "Adding availability time series data for $(asset_name) Generator to RT System..."
                PSY.add_time_series!(sys_RT,PSY.get_component(PSY.Generator,sys_RT, asset_name), RT_availability_forecast)
            catch ex
                @warn "Couldn't find a Generator with component name $(asset_name) in the RT PSY System. Proceeding without adding availability time series data for this component in the RT System."
            end
        end
    end

    @info "Succesfully added availability time series data to Generators in PSY DA and RT Systems."
    return sys_DA, sys_RT
end

#######################################################
# Generate Outage Profile for single stage SIIP Simulations
#######################################################
function add_csv_time_series_single_stage!(sys_DA::PSY.System, outage_csv_location::String;days_of_interest::Union{Nothing, UnitRange} = nothing,
                                           add_scenario::Union{Nothing, Int} = nothing)

    #######################################################
    # kwarg handling
    #######################################################
    @info "This script currently only adds availability time series to Generators in PSY System. This can be extended to handle Lines, Storage and Static Injections. "

    if (~isdir(outage_csv_location))
        error("Outage CSV location passed isn't a directory.")
    end

    (root, dirs, files) = first(walkdir(outage_csv_location))
    
    if (length(dirs) == 0)
        error("No scenario outage data available")
    end

    if (add_scenario === nothing)
        add_scenario = 1
        @warn  "The scenario to be used to get the asset availability time series wasn't passed. Using availability time series data for scenario '1'."
    end

    # Handling CC units using cc_restrictions.json
    cc_restrictions_dict_DA = Dict()
    for key in keys(cc_restrictions_util_file)
        cc_gens_DA =[]
        for gen_name in cc_restrictions_util_file[key]
            push!(cc_gens_DA,PSY.get_component(PSY.Generator,sys_DA, gen_name))
        end
            
        max_cap_idx_DA = argmax(PSY.get_max_active_power.(cc_gens_DA))
        length(max_cap_idx_DA) >1 ? push!(cc_restrictions_dict_DA,PSY.get_name(cc_gens_DA[max_cap_idx_DA[1]]) =>cc_gens_DA) : push!(cc_restrictions_dict_DA,PSY.get_name(cc_gens_DA[max_cap_idx_DA]) =>cc_gens_DA)
    end

    dir_location = joinpath(root,string(add_scenario))
    csv_locations = readdir(dir_location)

    if (~("Generator.csv" in csv_locations))
        error("Generator Availability time series data not available for scenario $(add_scenario).")
    end
    #file_location = joinpath(dir_location,csv_locations[1])
    file_location = joinpath(dir_location,"Generator.csv")

    # Handling days of interest to generate time stamps
    first_ts_temp_DA = first(PSY.get_time_series_multiple(sys_DA));
    len_ts_data_DA = length(first_ts_temp_DA.data);

    if (days_of_interest === nothing)
        days_of_interest = range(1,length = len_ts_data_DA)
        @warn  "No days_of_interest passed. Using all the days for which data is available in PSY System. Please make sure these days of interest align with the availability data in the CSV file."
    end

    #Select Full Days to avoid more Processing
    if (~(1<=days_of_interest.start <= len_ts_data_DA) || ~(1<=days_of_interest.stop <= len_ts_data_DA))
        error("Please checked the passed days of interest (e.g 1:24,25:48,1:365 etc.)")
    end
    
    num_days = length(days_of_interest);
    period_of_interest = range(days_of_interest.start==1 ? 1 : (24*days_of_interest.start)+1,length=num_days*24)
    N = length(period_of_interest);
    #######################################################
    # Timestamps
    #######################################################
    start_datetime_DA = PSY.IS.get_initial_timestamp(first_ts_temp_DA);
    sys_DA_res_in_hour = PSY.get_time_series_resolution(sys_DA)
    start_datetime_DA = start_datetime_DA + Dates.Hour((period_of_interest.start-1)*sys_DA_res_in_hour);
    finish_datetime_DA = start_datetime_DA +  Dates.Hour((N-1)*sys_DA_res_in_hour);
    all_timestamps = StepRange(start_datetime_DA, sys_DA_res_in_hour, finish_datetime_DA);
    ######################################################
    # Reading the CSV Files
    #######################################################
    df_outage_profile = DataFrames.DataFrame(CSV.File(file_location));

    for asset_name in names(df_outage_profile)
        # Creating TimeSeries Data
        DA_data = Dict()

        for (idx,timestamp) in enumerate(all_timestamps) #
            if (rem(idx,24) == 1)
                DA_availability_ts = df_outage_profile[idx:idx+23,asset_name]
                if (df_outage_profile[idx+23,asset_name] == 0)
                    append!(DA_availability_ts,zeros(12))
                else
                    append!(DA_availability_ts,ones(12))
                end

                push!(DA_data,timestamp => DA_availability_ts)
            end
        end

        DA_availability_forecast = PSY.Deterministic("outage", DA_data,sys_DA_res_in_hour)
       
        # Adding TimeSeries Data to PSY System
        if (asset_name in keys(cc_restrictions_dict_DA))
            for component in cc_restrictions_dict_DA[asset_name]
                try
                    @info "Adding availability time series data for $(PSY.get_name(component)) Generator to DA System..."
                    PSY.add_time_series!(sys_DA,component, DA_availability_forecast)
                catch ex
                    @warn "Couldn't find a Generator with component name $(PSY.get_name(component)) in the DA PSY System. Proceeding without adding availability time series data for this component in the DA System."
                end
            end
        else
            try
                @info "Adding availability time series data for $(asset_name) Generator to DA System..."
                PSY.add_time_series!(sys_DA,PSY.get_component(PSY.Generator,sys_DA, asset_name), DA_availability_forecast)
            catch ex
                @warn "Couldn't find a Generator with component name $(asset_name) in the DA PSY System. Proceeding without adding availability time series data for this component in the DA System."
            end
        end
    end

    @info "Succesfully added availability time series data to Generators in PSY DA System."
    return sys_DA
end


  
    




