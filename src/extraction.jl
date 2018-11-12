include("extraction/backcast.jl")
include("extraction/repra.jl")

function extract(params::ExtractionSpec, dt::DateTime,
                 system::SystemModel; copperplate::Bool=false)
    dt_idx = findfirstunique(system.timestamps, dt)
    return extract(params, dt_idx, system, copperplate=copperplate)
end

function extract_regional_distributions(
    system::SystemModel{N1,T1,N2,T2,P,E,V}, dt_idx::Int;
    copperplate::Bool=false) where {N1,T1,N2,T2,P,E,V}


    genset_idx = system.timestamps_generatorset[dt_idx]
    generators = view(system.generators, :, genset_idx)

    if copperplate
        gen_distrs = CapacityDistribution{V}[
            spconv([round(Int, gen.capacity) for gen in generators],
                   [gen.μ / (gen.μ + gen.λ) for gen in generators])]
        line_distrs = CapacityDistribution{V}[]
    else
        gen_distrs = convolvepartitions(generators, system.generators_regionstart)
        lineset_idx = system.timestamps_lineset[dt_idx]
        lines = view(system.lines, :, lineset_idx)
        line_distrs = convolvepartitions(lines, system.lines_interfacestart)
    end

    return (gen_distrs, line_distrs)

end

function convolvepartitions(assets::AbstractVector{<:AssetSpec{T}},
                            partitionstarts::Vector{Int}) where {T}

    n_assets = length(assets)
    n_partitions = length(partitionstarts)
    distrs = Vector{CapacityDistribution{T}}(n_partitions)

    for i in 1:n_partitions
        partitionstart = partitionstarts[i]
        partitionend = i < n_partitions ? partitionstarts[i+1]-1 : n_assets
        partitionassets = assets[partitionstart:partitionend]
        distrs[i] = spconv([round(Int, a.capacity) for a in partitionassets],
                           [a.μ / (a.μ + a.λ) for a in partitionassets])
    end

    return distrs

end

