struct SystemDistributionSet{T <: Real}
    timestamps::Vector{DateTime}
    gen_distrs::LimitDistributions{T}
    vgsamples::Matrix{T}
    interface_labels::Vector{Tuple{Int,Int}}
    interface_distrs::LimitDistributions{T}
    loadsamples::Matrix{T}
    hourwindow::Int
    daywindow::Int
end

function collapse(systemset::SystemDistributionSet{T}) where T

    vgsamples = sum(systemset.vgsamples, 1)
    loadsamples = sum(systemset.loadsamples, 1)

    gen_distr = systemset.gen_distrs[1]

    for i in 2:length(systemset.gen_distrs)
        gen_distr = add_dists(gen_distr, systemset.gen_distrs[i])
    end

    return SystemDistributionSet(
        systemset.timestamps, [gen_distr], vgsamples,
        Tuple{Int,Int}[], Generic{T,Float64,Vector{T}}[],
        loadsamples, systemset.hourwindow, systemset.daywindow)

end

function extract(dt::DateTime, systemset::SystemDistributionSet)

    sample_idxs = extract(dt, systemset.timestamps,
                          systemset.hourwindow,
                          systemset.daywindow)

    return SystemDistribution(systemset.gen_distrs,
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

# """
# data's first column should be a timestamp, and subsequent columns
# should be the system regions, in index order
# """
# function distributions(dt::DateTime, hour_window::Int, day_window::Int,
#                        data::DataFrame)
#     periods = DataFrame(Timestamp = window_periods(dt, hour_window, day_window))
#     data = join(data, periods, on=:Timestamp, kind=:semi)
#     prob = 1 ./ size(data, 1)
#     return [to_distr(Vector{Int}(data[region]), prob)
#             for region in names(data)[2:end]]
# end
