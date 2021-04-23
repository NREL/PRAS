#######################################################
# Surya
# NREL
# January 2020
# Make a smaller PRAS system (with a fewer timesteps)
# from a bigger PRAS system
#######################################################
# Main Function to reduce size of PRAS System
#######################################################
function SystemModel(pras_system::PRAS.SystemModel{N,L,T,P,E},period_of_interest::UnitRange)where {N,L,T,P,E}

    sys_type = typeof(pras_system);
    new_N = length(period_of_interest);

    @info "The original system is of type $(sys_type). You are trying to extract a SystemModel{$(new_N),$(L),$(T),$(P),$(E)} from the original system."
    if (N==new_N)
        @warn "The system is already of type $(sys_type)."
    end

    if (new_N>N)
        error("Cannot extract a SystemModel{$(new_N),$(L),$(T),$(P),$(E)} from $(sys_type).")
    end

    if (period_of_interest.start > N || period_of_interest.stop > N)
        error("Please check the system period of interest selected")
    end
 
    new_regions = PRAS.Regions{new_N,P}(pras_system.regions.names,pras_system.regions.load[:,period_of_interest])

    new_interfaces = PRAS.Interfaces{new_N,P}(pras_system.interfaces.regions_from, pras_system.interfaces.regions_to,
                        pras_system.interfaces.limit_forward[:,period_of_interest], pras_system.interfaces.limit_backward[:,period_of_interest]);

    new_generators = PRAS.Generators{new_N,L,T,P}(pras_system.generators.names,pras_system.generators.categories, 
                        pras_system.generators.capacity[:,period_of_interest],pras_system.generators.λ[:,period_of_interest],
                        pras_system.generators.μ[:,period_of_interest]);

    new_storage = PRAS.Storages{new_N,L,T,P,E}(pras_system.storages.names,pras_system.storages.categories,pras_system.storages.charge_capacity[:,period_of_interest],
                    pras_system.storages.discharge_capacity[:,period_of_interest],pras_system.storages.energy_capacity[:,period_of_interest],
                    pras_system.storages.charge_efficiency[:,period_of_interest],pras_system.storages.discharge_efficiency[:,period_of_interest],
                    pras_system.storages.carryover_efficiency[:,period_of_interest],pras_system.storages.λ[:,period_of_interest],pras_system.storages.μ[:,period_of_interest]);

    new_gen_stors = PRAS.GeneratorStorages{new_N,L,T,P,E}(pras_system.generatorstorages.names,pras_system.generatorstorages.categories, 
                    pras_system.generatorstorages.charge_capacity[:,period_of_interest],pras_system.generatorstorages.discharge_capacity[:,period_of_interest],
                    pras_system.generatorstorages.energy_capacity[:,period_of_interest],pras_system.generatorstorages.charge_efficiency[:,period_of_interest],
                    pras_system.generatorstorages.discharge_efficiency[:,period_of_interest],pras_system.generatorstorages.carryover_efficiency[:,period_of_interest], 
                    pras_system.generatorstorages.inflow[:,period_of_interest],pras_system.generatorstorages.gridwithdrawal_capacity[:,period_of_interest], 
                    pras_system.generatorstorages.gridinjection_capacity[:,period_of_interest],pras_system.generatorstorages.λ[:,period_of_interest],
                    pras_system.generatorstorages.μ[:,period_of_interest]);

    new_lines = PRAS.Lines{new_N,L,T,P}(pras_system.lines.names, pras_system.lines.categories,
                pras_system.lines.forward_capacity[:,period_of_interest], pras_system.lines.backward_capacity[:,period_of_interest],
                pras_system.lines.λ[:,period_of_interest], pras_system.lines.μ[:,period_of_interest]);

    new_system = PRAS.SystemModel(new_regions, new_interfaces, new_generators, pras_system.region_gen_idxs, new_storage, pras_system.region_stor_idxs,
                    new_gen_stors,pras_system.region_genstor_idxs, new_lines, pras_system.interface_line_idxs, pras_system.timestamps[period_of_interest]);
    
    @info "Successfully extracted a system of type $(typeof(new_system))."

    return new_system
end

function SystemModel(pras_system::PRAS.SystemModel{N,L,T,P,E},start_timestamp::TimeZones.ZonedDateTime,stop_timestamp::TimeZones.ZonedDateTime)where {N,L,T,P,E}

    if (~(start_timestamp in pras_system.timestamps) || ~(stop_timestamp in pras_system.timestamps))
        error("One of the timestamp is not part of the PRAS System. Please check the start and stop timestamps.")
    end

    if (stop_timestamp < start_timestamp)
        error("Please check the order of timestamps")
    end
    
    start =  Dates.value(T(start_timestamp - pras_system.timestamps.start))+1;
    length = Dates.value(T(stop_timestamp - start_timestamp))+1;

    new_system = SystemModel(pras_system,range(start,length=length));

    return new_system
end



    
