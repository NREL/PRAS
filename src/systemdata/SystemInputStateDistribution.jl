struct SystemInputStateDistribution{P<:PowerUnit}

    regions::Vector{CapacityDistribution}
    interfaces::Vector{CapacityDistribution}

    function SystemInputStateDistribution{}(
        system::SystemModel{N,L,T,P,E}, t::Int; copperplate::Bool=false
        ) where {N,L,T,P,E}

        region_starts = copperplate ? [1] : system.generators_regionstart
        interface_starts = copperplate ? Int[] : system.lines_interfacestart

        region_distrs = convolvepartitions(system.generators, region_starts, t)

        # Subtract load from available capacity
        if copperplate
            xs = support(region_distrs[1])
            xs .-= colsum(system.regions.load, t)
        else
            for r in 1:length(system.regions)
                xs = support(region_distrs[r])
                xs .-= system.regions.load[r, t]
            end
        end

        interface_distrs = convolvepartitions(system.lines, interface_starts, t)

        new{P}(region_distrs, interface_distrs)

    end

end

struct SystemInputStateSampler{P<:PowerUnit}
    regions::Vector{CapacitySampler}
    interfaces::Vector{CapacitySampler}
end

sampler(s::SystemInputStateDistribution{P}) where {P} =
        SystemInputStateSampler{P}(sampler.(s.regions), sampler.(s.interfaces))

function convolvepartitions(
    assets::AbstractAssets,
    partitionstarts::Vector{Int},
    t::Int)

    distrs = Vector{CapacityDistribution}(undef, length(partitionstarts))

    n_assets = length(assets)
    n_partitions = length(partitionstarts)

    for p in 1:n_partitions

        partitionstart = partitionstarts[p]
        partitionend = p < n_partitions ? partitionstarts[p+1]-1 : n_assets

        n_partition_assets = partitionend - partitionstart + 1
        capacities = Vector{Int}(undef, n_partition_assets)
        availabilities = Vector{Float64}(undef, n_partition_assets)
        j = 1

        for i in partitionstart:partitionend
            capacities[j] = capacity(assets)[i, t]
            μ = assets.μ[i, t]
            λ = assets.λ[i, t]
            availabilities[j] = μ / (μ + λ)
            j += 1
        end

        distrs[p] = spconv(capacities, availabilities)

    end

    return distrs

end

function rand!(rng::MersenneTwister, fp::FlowProblem,
               sampler::SystemInputStateSampler)

    slacknode = fp.nodes[end]
    nregions = length(sampler.regions)
    ninterfaces = length(sampler.interfaces)

    # Draw random capacity surplus / deficits
    for i in 1:nregions
        injection = rand(rng, sampler.regions[i])
        updateinjection!(fp.nodes[i], slacknode, injection)
    end

    # Assign random interface limits
    # TODO: Model seperate forward and reverse flow limits
    #       (based on common line outages)
    for i in 1:ninterfaces
        flowlimit = rand(rng, sampler.interfaces[i])
        updateflowlimit!(fp.edges[i], flowlimit) # Forward transmission
        updateflowlimit!(fp.edges[ninterfaces + i], flowlimit) # Reverse transmission
    end

    return fp

end
