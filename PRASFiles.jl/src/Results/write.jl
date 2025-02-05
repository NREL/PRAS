function generate_systemresult(results::R, pras_sys::SystemModel) where {R <: Tuple{Vararg{Result}}}
 
    shortfall_idx = findfirst(name.(typeof.(results)) .== ShortfallResult)
    shortfall = results[shortfall_idx]
    
    surplus_idx = findfirst(name.(typeof.(results)) .== SurplusResult)
    surplus = nothing
    if isnothing(surplus_idx)
        @warn "SurplusResult not available in the Result tuple. These results are not exported."
    else
        surplus = results[surplus_idx]
    end

    se_idx = findfirst(name.(typeof.(results)) .== StorageEnergyResult)
    storageenergy = nothing
    if isnothing(se_idx)
        if (length(pras_sys.storages.names) > 0)
            @warn "Storages are present in the SystemModel but StorageEnergyResult not available in the Result tuple.These results are not exported."
        end
    else
        storageenergy = results[se_idx]
    end

    region_results = RegionResult[]
    for (idx,reg_name) in enumerate(pras_sys.regions.names)
        region_gen_cats = unique(pras_sys.generators.categories[pras_sys.region_gen_idxs[idx]])
        region_stor_cats = unique(pras_sys.storages.categories[pras_sys.region_stor_idxs[idx]])
        append!(region_gen_cats,region_stor_cats)
        region_gen_cap = pras_sys.generators.capacity[pras_sys.region_gen_idxs[idx],:]
        region_stor_cap = pras_sys.storages.energy_capacity[pras_sys.region_stor_idxs[idx],:]

        installed_cap = Dict(region_gen_cats .=> [Vector{Int64}[] for i in range(1,length=length(region_gen_cats))])
        for (gen_idx,gen_cat) in enumerate(pras_sys.generators.categories[pras_sys.region_gen_idxs[idx]])
            push!(installed_cap[gen_cat],region_gen_cap[gen_idx,:])
        end
        for (gen_idx,gen_cat) in enumerate(pras_sys.storages.categories[pras_sys.region_stor_idxs[idx]])
            push!(installed_cap[gen_cat],region_stor_cap[gen_idx,:])
        end

        capacity = Dict(map(=>, keys(installed_cap), sum.(values(installed_cap))))
        peak_load = maximum(pras_sys.regions.load[idx,:])
        shortfall_mean = shortfall.shortfall_mean[idx,:]
        surplus_mean = 
        if isnothing(surplus)
            Float64[]
        else
            surplus.surplus_mean[idx,:]
        end
        
        reg_stor_SoC = Dict()
        if ~isnothing(storageenergy)
            for (i,stor) in enumerate(pras_sys.storages.names[pras_sys.region_stor_idxs[idx]])
                stor_energy_cap = maximum(pras_sys.storages.energy_capacity[pras_sys.region_stor_idxs[idx]][i,:])
                if (stor_energy_cap == 0)
                continue
                end
                stor_energy = storageenergy[stor, :]
                push!(reg_stor_SoC,stor =>  getindex.(stor_energy,1)/stor_energy_cap)
            end
        end
    
        storage_SoC = 
        if (isempty(reg_stor_SoC))
            Float64[]
        else
            sum(values(reg_stor_SoC))
        end
    
        shortfall_timestamps = collect(shortfall.timestamps)[findall(shortfall_mean .!= 0.0)]
        push!(region_results,
        RegionResult(
            reg_name,
            EUEResult(shortfall, region = reg_name),
            LOLEResult(shortfall, region = reg_name),
            neue(shortfall, pras_sys, region = reg_name),
            pras_sys.regions.load[idx,:],
            peak_load,
            capacity,
            shortfall_mean,
            surplus_mean,
            storage_SoC,
            shortfall_timestamps,
        )
        )

    end

    sys_result = SystemResult(
        shortfall.nsamples,
        TypeParams(pras_sys),
        collect(shortfall.timestamps),
        EUEResult(shortfall),
        LOLEResult(shortfall),
        neue(shortfall, pras_sys),
        region_results,
    )

    return sys_result

end

function save_aggregate_results(
    results::R,
    pras_sys::SystemModel;
    export_location::Union{Nothing, String}=nothing,
) where {R <: Tuple{Vararg{Result}}}
    @info "Only aggregate system and region level results are exported. Sample level results are not exported."

    if ~(ShortfallResult ∈ name.(typeof.(results)))
        error("ShortfallResult is not available in the Result tuple.")
    end

    if (export_location === nothing)
        export_location = pwd()
    end

    dt_now = format(now(), "dd-u-yy-H-M-S")
    export_location = joinpath(export_location, dt_now)
    if ~(isdir(export_location))
        mkpath(export_location)
    end

    sys_result = generate_systemresult(results, pras_sys);
    open(joinpath(export_location, "pras_results.json"), "w") do io
        pretty(io, sys_result)
    end

    @info "Successfully exported PRAS results here: $(export_location)"
    return export_location
end