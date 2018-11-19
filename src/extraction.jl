include("extraction/backcast.jl")
include("extraction/repra.jl")

"""
extract(::ExtractionSpec, system::SystemModel, dt::DateTime; copperplate::Bool=false)

Extracts a `SystemStateDistribution` from `system` corresponding to the point
in time `dt`, as prescribed by the supplied `ExtractionSpec`.

The optional keyword argument `copperplate` indicates whether or not to
collapse transmission as part of the extraction (for copperplate simulations,
this is much more efficient than collapsing the network on-the-fly).
"""
function extract(extractionspec::ExtractionSpec, dt::DateTime,
                 system::SystemModel; copperplate::Bool=false)

    dt_idx = findfirstunique(system.timestamps, dt)
    genset_idx = system.timestamps_generatorset[dt_idx]
    lineset_idx = system.timestamps_lineset[dt_idx]

    region_starts = copperplate ? [1] : system.generators_regionstart
    interface_starts = copperplate ? Int[] : system.lines_interfacestart

    genset = view(system.generators, :, genset_idx)
    region_distrs = convolvepartitions(genset, region_starts)

    lineset = view(system.lines, :, i)
    interface_distrs = convolvepartitions(lineset, interface_starts)

    return SystemStateDistribution(
        extractionspec, dt_idx, system,
        region_distrs, interface_distrs,
        copperplate)

end

"""
extract(::ExtractionSpec, system::SystemModel; copperplate::Bool=false)

Extracts a vector of `SystemStateDistribution`s from `system` for each time
period in the simulation, as prescribed by the supplied `ExtractionSpec`. This
method is generally much faster than extracting each time period seperately.

The optional keyword argument `copperplate` indicates whether or not to
collapse transmission as part of the extraction (for copperplate simulations,
this is much more efficient than collapsing the network on-the-fly).
"""
function extract(extractionspec::ExtractionSpec,
                 system::SystemModel{N1,T1,N2,T2,P,E,V};
                 copperplate::Bool=false) where {N1,T1,N2,T2,P,E,V}

    region_starts = copperplate ? [1] : system.generators_regionstart
    interface_starts = copperplate ? Int[] : system.lines_interfacestart

    n_timestamps = length(system.timestamps)
    n_regions = length(region_starts)
    n_gensets = size(system.generators, 2)
    n_interfaces = length(interface_starts)
    n_linesets = size(system.lines, 2)

    region_distrs = Matrix{CapacityDistribution{V}}(n_regions, n_gensets)
    Threads.@threads for i in 1:n_gensets
        genset = view(system.generators, :, i)
        genset_regions = view(region_distrs, :, i)
        convolvepartitions!(genset_regions, genset, region_starts)
    end

    interface_distrs = Matrix{CapacityDistribution{V}}(n_interfaces, n_linesets)
    Threads.@threads for i in 1:n_linesets
        lineset = view(system.lines, :, i)
        lineset_interfaces = view(interface_distrs, :, i)
        convolvepartitions!(lineset_interfaces, lineset, interface_starts)
    end

    results = Vector{SystemStateDistribution{N1,T1,P,E,V}}(n_timestamps)
    Threads.@threads for t in 1:n_timestamps
        results[t] = SystemStateDistribution(
            extractionspec, t, system,
            region_distrs[:, system.timestamps_generatorset[t]],
            interface_distrs[:, system.timestamps_lineset[t]],
            copperplate)
    end

    return results

end

function convolvepartitions(assets::AbstractVector{<:AssetSpec{T}},
                           partitionstarts::Vector{Int}) where {T}
    distrs = Vector{CapacityDistribution{T}}(length(partitionstarts))
    return convolvepartitions!(distrs, assets, partitionstarts)
end

function convolvepartitions!(distrs::AbstractVector{CapacityDistribution{T}},
                             assets::AbstractVector{<:AssetSpec{T}},
                             partitionstarts::Vector{Int}) where {T}

    n_assets = length(assets)
    n_partitions = length(partitionstarts)
    @assert length(distrs) == n_partitions

    for i in 1:n_partitions
        partitionstart = partitionstarts[i]
        partitionend = i < n_partitions ? partitionstarts[i+1]-1 : n_assets
        partitionassets = assets[partitionstart:partitionend]
        distrs[i] = spconv([round(Int, a.capacity) for a in partitionassets],
                           [a.μ / (a.μ + a.λ) for a in partitionassets])
    end

    return distrs

end
