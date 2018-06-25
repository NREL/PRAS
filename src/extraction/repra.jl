struct REPRA <: ExtractionSpec
    hourwindow::Int
    daywindow::Int

    function REPRA(h::Int, d::Int)
        @assert h >= 0
        @assert d >= 0
        new(h, d)
    end
end

function window_periods(dt::DateTime, hour_window::Int, day_window::Int)

    # TODO: This approach is fragile - switch to something that uses
    #       continuous windows instead of generating and matching
    #       discrete points in time

    # dt time should be xx:00:00
    return [dt + day_offset + hour_offset
            for day_offset in Day(-day_window):Day(1):Day(day_window)
            for hour_offset in Hour(-hour_window):Hour(1):Hour(hour_window)]

end

function extract(params::REPRA, dt::DateTime,
                 systemset::SystemDistributionSet{N1,T1,N2,T2,P}) where {N1,T1,N2,T2,P}

    vg_sample_idxs = extract(dt, systemset.timestamps,
                             params.hourwindow,
                             params.daywindow)
    load_sample_idxs = findin(systemset.timestamps, [dt])

    return SystemDistribution{1,Hour,P}(
        systemset.region_labels,
        systemset.region_maxdispatchabledistrs,
        systemset.vgsamples[:, vg_sample_idxs],
        systemset.interface_labels,
        systemset.interface_maxflowdistrs,
        systemset.loadsamples[:, load_sample_idxs])

end

function extract(dt::DateTime, dts::Vector{DateTime},
                 hourwindow::Int, daywindow::Int)
    periods = window_periods(dt, hourwindow, daywindow)
    return findin(dts, periods)
end
