#######################################################
# Surya
# NREL
# January 2020
# Make a smaller PRAS system (with a fewer timesteps)
# from a bigger PRAS system
#######################################################
# Main Function to reduce size of PRAS System
#######################################################
function reduce_pras_system_size(pras_system::PRAS.SystemModel,period_of_interest::UnitRange)
    """
    reduce_system_size(sys,x)

    Build a smaller PRAS system with 'x' time_steps from a larger PRAS System.
    
    ...
    # Arguments
    - `sys::SystemModel`: Original PRAS System.
    - `x::UnitRange`: Period of interest to build smaller PRAS System
    ...

    # Examples
    ```julia-repl
    julia> reduce_system_size(sys,range(100,length=100))
    SystemModel{100,timestep_length,timeunits,powerunits,energyunits(optional)}
    ```
    """
    symbol = PRAS.unitsymbol(pras_system);
    time_steps = length(pras_system.regions.load[1,:]);
    
    time_units_symbol = symbol[1];
    power_units_symbol = symbol[2];
    energy_units_symbol = symbol[3];

    time_units = PRAS.PRASBase.timeunits[time_units_symbol];
    power_units = PRAS.PRASBase.powerunits[power_units_symbol];
    energy_units = PRAS.PRASBase.energyunits[energy_units_symbol];
    
    sys_type = typeof(pras_system);

    @info "The original system is of type $(sys_type). You are trying to build a system of type SystemModel{$(length(period_of_interest)),
           1,$(time_units),$(power_units),$(energy_units)}."
    if (time_steps==length(period_of_interest))
        @warn "The system is already of type $(sys_type)."

    elseif (length(period_of_interest)>time_steps)
        @error "Cannot build a SystemModel{$(length(period_of_interest)),1,$(time_units),$(power_units),$(energy_units)} from $(sys_type)."
    else

        new_regions = PRAS.Regions{length(period_of_interest),power_units}(pras_system.regions.names,pras_system.regions.load[:,period_of_interest])

        new_interfaces = PRAS.Interfaces{length(period_of_interest),power_units}(pras_system.interfaces.regions_from, pras_system.interfaces.regions_to,
                         pras_system.interfaces.limit_forward[:,period_of_interest], pras_system.interfaces.limit_backward[:,period_of_interest]);

        new_generators = PRAS.Generators{length(period_of_interest),1,time_units,power_units}(pras_system.generators.names,pras_system.generators.categories, 
                         pras_system.generators.capacity[:,period_of_interest],pras_system.generators.λ[:,period_of_interest],
                         pras_system.generators.μ[:,period_of_interest]);

        new_storage = PRAS.Storages{length(period_of_interest),1,time_units,power_units,energy_units}(pras_system.storages.names,
                      pras_system.storages.categories,pras_system.storages.charge_capacity[:,period_of_interest],
                      pras_system.storages.discharge_capacity[:,period_of_interest],pras_system.storages.energy_capacity[:,period_of_interest],
                      pras_system.storages.charge_efficiency[:,period_of_interest],pras_system.storages.discharge_efficiency[:,period_of_interest],
                      pras_system.storages.carryover_efficiency[:,period_of_interest],pras_system.storages.λ[:,period_of_interest],
                      pras_system.storages.μ[:,period_of_interest]);

        new_gen_stors = PRAS.GeneratorStorages{length(period_of_interest),1,time_units,power_units,energy_units}(pras_system.generatorstorages.names,
                        pras_system.generatorstorages.categories, pras_system.generatorstorages.charge_capacity[:,period_of_interest],
                        pras_system.generatorstorages.discharge_capacity[:,period_of_interest],
                        pras_system.generatorstorages.energy_capacity[:,period_of_interest],
                        pras_system.generatorstorages.charge_efficiency[:,period_of_interest],
                        pras_system.generatorstorages.discharge_efficiency[:,period_of_interest],
                        pras_system.generatorstorages.carryover_efficiency[:,period_of_interest], 
                        pras_system.generatorstorages.inflow[:,period_of_interest],pras_system.generatorstorages.gridwithdrawal_capacity[:,period_of_interest], 
                        pras_system.generatorstorages.gridinjection_capacity[:,period_of_interest],pras_system.generatorstorages.λ[:,period_of_interest],
                        pras_system.generatorstorages.μ[:,period_of_interest]);

        new_lines = PRAS.Lines{length(period_of_interest),1,time_units,power_units}(pras_system.lines.names, pras_system.lines.categories,
                    pras_system.lines.forward_capacity[:,period_of_interest], pras_system.lines.backward_capacity[:,period_of_interest],
                    pras_system.lines.λ[:,period_of_interest], pras_system.lines.μ[:,period_of_interest]);

        new_system = PRAS.SystemModel(new_regions, new_interfaces, new_generators, pras_system.region_gen_idxs, new_storage, pras_system.region_stor_idxs,
                     new_gen_stors,pras_system.region_genstor_idxs, new_lines, pras_system.interface_line_idxs, pras_system.timestamps[period_of_interest]);
        
        @info "Successfully built a system of type $(typeof(new_system))."
    end
    return new_system
end



    
