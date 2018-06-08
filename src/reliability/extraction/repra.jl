struct REPRA <: SinglePeriodExtractionMethod
    hourwindow::Int
    daywindow::Int

    function REPRA(h::Int, d::Int)
        @assert h >= 0
        @assert d >= 0
        new(h, d)
    end
end

function window_periods(dt::DateTime, hour_window::Int, day_window::Int)

    # dt time should be xx:00:00 TODO: Assert that
    return [dt + day_offset + hour_offset
            for day_offset in Day(-day_window):Day(1):Day(day_window)
            for hour_offset in Hour(-hour_window):Hour(1):Hour(hour_window)]

end

function extract(params::REPRA, dt::DateTime,
                 systemset::SystemDistributionSet{N1,T1,N2,T2,P}) where {N1,T1,N2,T2,P}

    vg_sample_idxs = extract(dt, systemset.timestamps,
                             params.hourwindow,
                             params.daywindow)
    load_sample_idx = searchsorted(systemset.timestamps, dt)[1]

    return SystemDistribution{1,Hour,P}(systemset.gen_distrs,
                                        systemset.vgsamples[:, vg_sample_idxs],
                                        systemset.interface_labels,
                                        systemset.interface_distrs,
                                        systemset.loadsamples[:, [load_sample_idx]])

end

function extract(dt::DateTime, dts::Vector{DateTime},
                 hourwindow::Int, daywindow::Int)
    periods = window_periods(dt, hourwindow, daywindow)
    return findin(dts, periods)
end
