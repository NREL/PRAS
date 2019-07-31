struct SystemInputStateDistribution{N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real,
    VCDV<:AbstractVector{CapacityDistribution{V}},
    VCSV<:AbstractVector{CapacitySampler{V}},
    MV<:AbstractMatrix{V}}

    region_idxs::Base.OneTo{Int}
    region_labels::Vector{String}
    region_maxdispatchabledistrs::VCDV
    region_maxdispatchablesamplers::VCSV
    vgsample_idxs::Base.OneTo{Int}
    vgsamples::MV
    interface_idxs::Base.OneTo{Int}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_maxflowdistrs::VCDV
    interface_maxflowsamplers::VCSV
    loadsample_idxs::Base.OneTo{Int}
    loadsamples::MV

    # Multi-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        region_labels::Vector{String},
        region_maxdispatchabledistrs::VCDV,
        region_maxdispatchablesamplers::VCSV,
        vgsamples::MV,
        interface_labels::Vector{Tuple{Int,Int}},
        interface_maxflowdistrs::VCDV,
        interface_maxflowsamplers::VCSV,
        loadsamples::MV) where {
            N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V,
            VCDV<:AbstractVector{CapacityDistribution{V}},
            VCSV<:AbstractVector{CapacitySampler{V}},
            MV<:AbstractMatrix{V}}

        n_regions = length(region_labels)
        region_idxs = Base.OneTo(n_regions)
        @assert length(region_maxdispatchabledistrs) == n_regions
        @assert size(vgsamples, 1) == n_regions
        @assert size(loadsamples, 1) == n_regions

        n_interfaces = length(interface_labels)
        interface_idxs = Base.OneTo(n_interfaces)
        @assert n_interfaces == length(interface_maxflowdistrs)

        n_vgsamples = size(vgsamples, 2)
        vgsample_idxs = Base.OneTo(n_vgsamples)

        n_loadsamples = size(loadsamples, 2)
        loadsample_idxs = Base.OneTo(n_loadsamples)

        new{N,T,P,E,V,VCDV,VCSV,MV}(
            region_idxs, region_labels,
            region_maxdispatchabledistrs,
            region_maxdispatchablesamplers,
            vgsample_idxs, vgsamples,
	    interface_idxs, interface_labels,
            interface_maxflowdistrs,
            interface_maxflowsamplers,
            loadsample_idxs, loadsamples)

    end

    # Single-region constructor
    function SystemInputStateDistribution{N,T,P,E}(
        maxdispatchable_distr::CapacityDistribution{V},
        maxdispatchable_sampler::CapacitySampler{V},
        vgsamples::Vector{V}, loadsamples::Vector{V}
    ) where {N,T<:Period,P<:PowerUnit,E<:EnergyUnit,V}

        new{N,T,P,E,V,Vector{CapacityDistribution{V}},
                      Vector{CapacitySampler{V}},Matrix{V}}(
            Base.OneTo(1), ["Region"],
            [maxdispatchable_distr], [maxdispatchable_sampler],
            Base.OneTo(length(vgsamples)), reshape(vgsamples, 1, :),
            Base.OneTo(0), Tuple{Int,Int}[],
            CapacityDistribution{V}[], CapacitySampler{V}[],
            Base.OneTo(length(loadsamples)), reshape(loadsamples, 1, :))

    end

end

function rand!(rng::MersenneTwister, fp::FlowProblem,
                      system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}

    slacknode = fp.nodes[end]
    ninterfaces = length(system.interface_labels)

    vgsample_idx = rand(rng, system.vgsample_idxs)
    loadsample_idx = rand(rng, system.loadsample_idxs)

    # Draw random capacity surplus / deficits
    for i in system.region_idxs
        updateinjection!(
            fp.nodes[i], slacknode, round(Int,
            rand(rng, system.region_maxdispatchablesamplers[i]) + # Dispatchable generation
            system.vgsamples[i, vgsample_idx] - # Variable generation
            system.loadsamples[i, loadsample_idx] # Load
        ))
    end

    # Assign random line limits
    for ij in system.interface_idxs
        i, j = system.interface_labels[ij]
        flowlimit = round(Int, rand(rng, system.interface_maxflowsamplers[ij]))
        updateflowlimit!(fp.edges[ij], flowlimit) # Forward transmission
        updateflowlimit!(fp.edges[ninterfaces + ij], flowlimit) # Reverse transmission
    end

    return fp

end

function rand(rng::MersenneTwister, fp::FlowProblem,
                   system::SystemInputStateDistribution{N,T,P,E,V}
    ) where {N,T,P,E,V}
    return rand!(rng, FlowProblem(system), system)
end
