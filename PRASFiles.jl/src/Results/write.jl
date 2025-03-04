"""
    generate_systemresult(shortfall::ShortfallResult, pras_sys::SystemModel)

Generate PRASFiles.jl SystemResult from PRASCore.jl ShortfallResult  

# Arguments

    - `shortfall::ShortfallResult`: ShortfallResult 
    - `pras_sys::SystemModel`: PRAS SystemModel

# Returns

  - SystemResult.
"""
function generate_systemresult(shortfall::ShortfallResult, pras_sys::SystemModel)
    
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
        shortfall_timestamps = collect(shortfall.timestamps)[findall(shortfall_mean .!= 0.0)]

        push!(region_results,
        RegionResult(
            reg_name,
            EUEResult(shortfall, region = reg_name),
            LOLEResult(shortfall, region = reg_name),
            NEUEResult(shortfall, pras_sys, region = reg_name),
            pras_sys.regions.load[idx,:],
            peak_load,
            capacity,
            shortfall_mean,
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
        NEUEResult(shortfall, pras_sys),
        region_results,
    )

    return sys_result

end

"""
    saveshortfall(
        shortfall::ShortfallResult,
        pras_sys::SystemModel,
        outfile::String,
    )

Save ShortfallResult in JSON format. Only aggregate system and region level results are exported. Sample level results are not exported..

# Arguments

    - `shortfall::ShortfallResult`: ShortfallResult 
    - `pras_sys::SystemModel`: PRAS SystemModel
    - `outfile::String`: Location to save the ShortfallResult

# Returns

  - ShortfallResult saved in a JSON format.
"""
function saveshortfall(
    shortfall::ShortfallResult,
    pras_sys::SystemModel,
    outfile::String,
)

    dt_now = format(now(), "dd-u-yy-H-M-S")
    export_location = joinpath(outfile, dt_now)
    if ~(isdir(export_location))
        mkpath(export_location)
    end

    sys_result = generate_systemresult(shortfall, pras_sys);
    open(joinpath(export_location, "pras_results.json"), "w") do io
        pretty(io, sys_result)
    end

    @info "Successfully exported PRAS ShortfallResult here: $(export_location)"
    return export_location
end

function saveshortfall(
    shortfall::R,
    pras_sys::SystemModel,
    outfile::String,
) where {R <: Result}

    error("saveshortfall is not implemented for $(typeof(shortfall))")
end