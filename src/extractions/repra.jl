struct REPRA <: ExtractionSpec
    hourwindow::Int
    daywindow::Int

    function REPRA(h::Int, d::Int)
        @assert h >= 0
        @assert d >= 0
        new(h, d)
    end
end

function SystemInputStateDistribution(
    params::REPRA, dt_idx::Int,
    system::SystemModel{N,L,T,P,E,V},
    region_distrs::AbstractVector{CapacityDistribution{V}},
    region_samplers::AbstractVector{CapacitySampler{V}},
    interface_distrs::AbstractVector{CapacityDistribution{V}},
    interface_samplers::AbstractVector{CapacitySampler{V}},
    copperplate::Bool=false) where {N,L,T,P,E,V}

    dt = system.timestamps[dt_idx]
    vg_sample_idxs = window_idxs(
        dt, system.timestamps, params.hourwindow, params.daywindow)

    vg = view(system.vg, :, vg_sample_idxs)
    load = view(system.load, :, vg_sample_idxs)

    if copperplate
        vg = vec(sum(vg, dims=1))
        load = vec(sum(load, dims=1))
        result = SystemInputStateDistribution{L,T,P,E}(
            region_distrs[1], region_samplers[1], vg, load)
    else
        result = SystemInputStateDistribution{L,T,P,E}(
            system.regions, region_distrs, region_samplers, vg,
            system.interfaces, interface_distrs, interface_samplers, load)
    end

    return result

end

function window_idxs(dt::DateTime, dts::StepRange{DateTime},
                     hourwindow::Int, daywindow::Int)

    hour_offset = Hour(hourwindow)
    periodranges = [
        (dt + day_offset - hour_offset, dt + day_offset + hour_offset)
        for day_offset in Day(-daywindow):Day(1):Day(daywindow)]

    # TODO: Algorithmic improvements possible since both
    #       dts and periods are sorted. Could also pre-allocate a max-length
    #       include_idxs and resize at the end to avoid repeated pushes
    include_idxs = Int[]
    for (i, dt_i) in enumerate(dts)
        any(range -> range[1] <= dt_i <= range[2], periodranges)
        push!(include_idxs, i)
    end 

    return include_idxs

end
