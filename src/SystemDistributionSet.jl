struct SystemDistributionSet{N1,T1<:Period,N2,T2<:Period,P<:PowerUnit,V<:Real}
    timestamps::Vector{DateTime}
    gen_distrs::LimitDistributions{V}
    vgsamples::Matrix{V}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_distrs::LimitDistributions{V}
    loadsamples::Matrix{V}
    hourwindow::Int
    daywindow::Int
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

"""
Extract a single hourly SystemDistribution corresponding to dt
from SystemDistributionSet data
"""
function extract(dt::DateTime, systemset::SystemDistributionSet{N1,T1,N2,T2,P}) where {N1,T1,N2,T2,P}

    sample_idxs = extract(dt, systemset.timestamps,
                          systemset.hourwindow,
                          systemset.daywindow)

    return SystemDistribution{1,Hour,P}(systemset.gen_distrs,
                                       systemset.vgsamples[:, sample_idxs],
                                       systemset.interface_labels,
                                       systemset.interface_distrs,
                                       systemset.loadsamples[:, sample_idxs])

end

function extract(dt::DateTime, dts::Vector{DateTime},
                 hourwindow::Int, daywindow::Int)
    periods = window_periods(dt, hourwindow, daywindow)
    return findin(dts, periods)
end

# Extraction helper functions

daytype(dt::DateTime) = dayofweek(dt) < 6 ? :Weekday : :Weekend

function window_periods(dt::DateTime, hour_window::Int, day_window::Int)

    dt_type = daytype(dt)

    # dt time should be xx:00:00
    return [dt + day_offset + hour_offset
            for day_offset in Day(-day_window):Day(1):Day(day_window)
            for hour_offset in Hour(-hour_window):Hour(1):Hour(hour_window)
            if daytype(dt + day_offset + hour_offset) == dt_type]

end
