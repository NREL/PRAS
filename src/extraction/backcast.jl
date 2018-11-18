struct Backcast <: ExtractionSpec end

function SystemStateDistribution(
    extraction_spec::Backcast, dt_idx::Int,
    system::SystemModel{N1,T1,N2,T2,P,E,V},
    region_distrs::AbstractVector{CapacityDistribution{V}},
    interface_distrs::AbstractVector{CapacityDistribution{V}},
    copperplate::Bool=false) where {N1,T1,N2,T2,P,E,V}

    vg = system.vg[:, [dt_idx]]
    load = system.load[:, [dt_idx]]

    if copperplate
        vg = vec(sum(vg, 1))
        load = vec(sum(load, 1))
        result = SystemStateDistribution{N1,T1,P,E}(region_distrs[1], vg, load)
    else
        result = SystemStateDistribution{N1,T1,P,E}(
            system.regions, region_distrs, vg,
            system.interfaces, interface_distrs, load)
    end

    return result

end
