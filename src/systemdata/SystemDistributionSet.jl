struct SystemDistributionSet{N1,T1<:Period,N2,T2<:Period,
                             P<:PowerUnit,E<:EnergyUnit,V<:Real}
    timestamps::Vector{DateTime}
    region_labels::Vector{String}
    region_maxdispatchabledistrs::Vector{CapacityDistribution{V}}
    vgsamples::Matrix{V}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_maxflowdistrs::Vector{CapacityDistribution{V}}
    loadsamples::Matrix{V}

    function SystemDistributionSet{N1,T1,N2,T2,P,E}(
        timestamps::Vector{DateTime},
        region_labels::Vector{String},
        region_maxdispatchabledistrs::Vector{CapacityDistribution{V}},
        vgsamples::Matrix{V},
        interface_labels::Vector{Tuple{Int,Int}},
        interface_maxflowdistrs::Vector{CapacityDistribution{V}},
        loadsamples::Matrix{V}
    ) where {N1,T1<:Period,N2,T2<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

        n_regions = length(region_labels)
        n_periods = length(timestamps)
        @assert size(vgsamples) == (n_regions, n_periods)
        @assert size(loadsamples) == (n_regions, n_periods)

        new{N1,T1,N2,T2,P,E,V}(
            timestamps,
            region_labels, region_maxdispatchabledistrs,
            vgsamples,
            interface_labels, interface_maxflowdistrs,
            loadsamples)

    end

end

function collapse(systemset::SystemDistributionSet{N1,T1,N2,T2,P,E,V}
                  ) where {N1,T1,N2,T2,P,E,V}

    vgsamples = sum(systemset.vgsamples, 1)
    loadsamples = sum(systemset.loadsamples, 1)

    gen_distr = systemset.region_maxdispatchabledistrs[1]

    for i in 2:length(systemset.region_maxdispatchabledistrs)
        gen_distr = add_dists(
            gen_distr, systemset.region_maxdispatchabledistrs[i])
    end

    return SystemDistributionSet{N1,T1,N2,T2,P,E,V}(
        systemset.timestamps, [gen_distr], vgsamples,
        Tuple{Int,Int}[], Generic{V,Float64,Vector{V}}[],
        loadsamples, systemset.hourwindow, systemset.daywindow)

end
