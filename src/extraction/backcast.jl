struct Backcast <: ExtractionSpec end

function extract(params::Backcast, dt_idx::Int,
                 system::SystemModel{N1,T1,N2,T2,P,E};
                 copperplate::Bool=false) where {N1,T1,N2,T2,P,E}

    gendistrs, interfacedistrs = extract_regional_distributions(
        system, dt_idx, copperplate=copperplate)
    vg = system.vg[:, [dt_idx]]
    load = system.load[:, [dt_idx]]

    if copperplate
        vg = sum(vg, 1)
        load = sum(load, 1)
        result = SystemStateDistribution{N1,T1,P,E}(gendistrs[1], vg, load)
    else
        result = SystemStateDistribution{N1,T1,P,E}(
            system.regions, gendistrs, vg,
            system.interfaces, interfacedistrs, load)
    end

    return result

end
