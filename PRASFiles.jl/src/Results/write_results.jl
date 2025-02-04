function write_aggregate_results(results::R, pras_sys::SystemModel) {R <: Tuple{Vararg{Result}}}

    shortfall = results[1]
    surplus = results[2]
    storage_SoC = results[3]
    
    region_results = RegionResult[]
    for (idx,reg_name) in enumerate(pras_sys.regions.names)
        region_gen_cats = unique(pras_sys.generators.categories[pras_sys.region_gen_idxs[idx]])
        region_stor_cats = unique(pras_sys.storages.categories[pras_sys.region_stor_idxs[idx]])
        append!(region_gen_cats,region_stor_cats)

        region_gen_cap = pras_sys.generators.capacity[pras_sys.region_gen_idxs[idx],:]
        region_stor_cap = pras_sys.storages.energy_capacity[pras_sys.region_stor_idxs[idx],:]
    end
end
