struct REPRA <: SinglePeriodExtractionMethod
    hourwindow::Int,
    daywindow::Int

    function REPRA(h::Int, d::Int)
        @assert h >= 0
        @assert d >= 0
        new(h, d)
    end
end

daytype(dt::DateTime) = dayofweek(dt) < 6 ? :Weekday : :Weekend

function window_periods(dt::DateTime, hour_window::Int, day_window::Int)

    dt_type = daytype(dt)

    # dt time should be xx:00:00 TODO: Assert that
    return [dt + day_offset + hour_offset
            for day_offset in Day(-day_window):Day(1):Day(day_window)
            for hour_offset in Hour(-hour_window):Hour(1):Hour(hour_window)
            if daytype(dt + day_offset + hour_offset) == dt_type]

end

function extract(params::REPRA, dt::DateTime,
                 systemset::SystemDistributionSet{N1,T1,N2,T2,P}) where {N1,T1,N2,T2,P}

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
