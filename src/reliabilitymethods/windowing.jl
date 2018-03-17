daytype(dt::DateTime) = dayofweek(dt) < 6 ? :Weekday : :Weekend

function to_distr(vs::Vector, p::Float64)
    cmap = countmap(vs)
    return Generic(collect(keys(cmap)),
                   [p * w for w in values(cmap)])
end

function window_periods(dt::DateTime, hour_window::Int, day_window::Int)

    dt_type = daytype(dt)

    # dt time should be xx:00:00
    return [dt + day_offset + hour_offset
            for day_offset in Day(-day_window):Day(1):Day(day_window)
            for hour_offset in Hour(-hour_window):Hour(1):Hour(hour_window)
            if daytype(dt + day_offset + hour_offset) == dt_type]

end

"""
data's first column should be a timestamp, and subsequent columns
should be the system regions, in index order
"""
function distributions(dt::DateTime, hour_window::Int, day_window::Int,
                       data::DataFrame)
    periods = DataFrame(Timestamp = window_periods(dt, hour_window, day_window))
    data = join(data, periods, on=:Timestamp, kind=:semi)
    prob = 1 ./ size(data, 1)
    return [to_distr(Vector{Float64}(data[region]), prob)
            for region in names(data)[2:end]]
end
