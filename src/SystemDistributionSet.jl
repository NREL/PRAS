struct SystemDistributionSet{N1,T1<:Period,N2,T2<:Period,P<:PowerUnit,V<:Real}
    timestamps::Vector{DateTime}
    gen_distrs::LimitDistributions{V}
    vgsamples::Matrix{V}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_distrs::LimitDistributions{V}
    loadsamples::Matrix{V}
    hourwindow::Int #TODO: Remove
    daywindow::Int #TODO: Remove

    function SystemDistributionSet{N1,T1,N2,T2,P,V}(
        timestamps::Vector{DateTime}, gen_distrs::LimitDistributions{V}, vgsamples::Matrix{V},
        interface_labels::Vector{Tuple{Int,Int}}, interface_distrs::LimitDistributions{V},
        loadsamples::Matrix{V}, hourwindow::Int, daywindow::Int
    ) where {N1,T1<:Period,N2,T2<:Period,P<:PowerUnit,V<:Real}

        n_regions = length(gen_distrs)
        n_periods = length(timestamps)
        @assert size(vgsamples) == (n_regions, n_periods)
        @assert size(loadsamples) == (n_regions, n_periods)

        new{N1,T1,N2,T2,P,V}(
            timestamps, gen_distrs, vgsamples,
            interface_labels, interface_distrs,
            loadsamples, hourwindow, daywindow)

    end
end

function collapse(systemset::SystemDistributionSet{N1,T1,N2,T2,P,V}) where {N1,T1,N2,T2,P,V}

    vgsamples = sum(systemset.vgsamples, 1)
    loadsamples = sum(systemset.loadsamples, 1)

    gen_distr = systemset.gen_distrs[1]

    for i in 2:length(systemset.gen_distrs)
        gen_distr = add_dists(gen_distr, systemset.gen_distrs[i])
    end

    return SystemDistributionSet{N1,T1,N2,T2,P,V}(
        systemset.timestamps, [gen_distr], vgsamples,
        Tuple{Int,Int}[], Generic{V,Float64,Vector{V}}[],
        loadsamples, systemset.hourwindow, systemset.daywindow)

end
