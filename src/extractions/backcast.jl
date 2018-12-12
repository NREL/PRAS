struct Backcast <: ExtractionSpec end

function SystemInputStateDistribution(
    extraction_spec::Backcast, dt_idx::Int,
    system::SystemModel{N,L,T,P,E,V},
    region_distrs::AbstractVector{CapacityDistribution{V}},
    region_samplers::AbstractVector{CapacitySampler{V}},
    interface_distrs::AbstractVector{CapacityDistribution{V}},
    interface_samplers::AbstractVector{CapacitySampler{V}},
    copperplate::Bool=false) where {N,L,T,P,E,V}

    vg = system.vg[:, [dt_idx]]
    load = system.load[:, [dt_idx]]

    if copperplate
        vg = vec(sum(vg, 1))
        load = vec(sum(load, 1))
        result = SystemInputStateDistribution{L,T,P,E}(
            region_distrs[1], region_samplers[1], vg, load)
    else
        result = SystemInputStateDistribution{L,T,P,E}(
            system.regions, region_distrs, region_samplers, vg,
            system.interfaces, interface_distrs, interface_samplers, load)
    end

    return result

end
