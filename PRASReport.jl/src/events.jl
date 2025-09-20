mutable struct Event{N,L,T,E}
    name::String
    timestamps::StepRange{ZonedDateTime,T}
    system_lole::LOLE
    system_eue::EUE
    system_neue::NEUE
    lole::Vector{LOLE}
    eue::Vector{EUE}
    neue::Vector{NEUE}
    regions::Vector{String}

    function Event{}(name::String, timestamps::StepRange{ZonedDateTime,T}, 
                     system_lole::LOLE{N,L,T}, system_eue::EUE{N,L,T,E},
                     system_neue::NEUE,
                     lole::Vector{LOLE{N,L,T}}, eue::Vector{EUE{N,L,T,E}}, 
                     neue::Vector{NEUE}, 
                     regions::Vector{String}
                    ) where {N,L,T,E}

        length(lole) != length(eue) != length(neue) != length(regions) && 
            error("Length of lole, eue, neue, and region names vectors must be equal")

        length(timestamps) != N &&
            error("Number of timesteps should match metrics event length")

        length(regions) > 0 && !isapprox(val(system_eue),sum(val.(eue))) &&
            error("System EUE should be approximately the sum of EUE of all the regions")

        new{N,L,T,E}(name, timestamps, 
                    system_lole, system_eue, system_neue,
                    lole, eue, neue, regions)
    end
end

mutable struct Shortfall_timeseries{}
    name::String
    timestamps::Vector{ZonedDateTime}
    eue::Vector{Vector{Float64}}
    lole::Vector{Vector{Float64}}
    neue::Vector{Vector{Float64}}
    regions::Vector{String}

    function Shortfall_timeseries(event,sf::ShortfallResult{N,L,T,E}) where {N,L,T,E}
        name = event.name
        timestamps = collect(event.timestamps)
        eue = map(row->val.(row),(EUE.(sf,:,timestamps)))
        lole = map(row->val.(row),(LOLE.(sf,:,timestamps)))
        neue = map(row->val.(row),(NEUE.(sf,:,timestamps)))
        regions = event.regions
        new(name,timestamps,eue,lole,neue,regions)
    end
end

mutable struct Flow_timeseries{}
    name::String
    timestamps::Vector{ZonedDateTime}
    flow::Vector{Vector{NEUE}}
    interfaces::Vector{String}
    function Flow_timeseries(timestamps::Vector{ZonedDateTime})
        new(timestamps)
    end
end


event_length(event::Event{N,L,T}) where {N,L,T} = T(N*L)

function Event(sf::ShortfallResult{N,L,T,E}, 
                event_timestamps::StepRange{ZonedDateTime,T}, 
                name::String=nothing
                ) where {N,L,T,E}

    if isnothing(name)
        name = "Shortfall Event"
    end

    event_length = length(event_timestamps)
    ts_first = findfirstunique(sf.timestamps,first(event_timestamps))
    ts_last = findfirstunique(sf.timestamps,last(event_timestamps))

    system_lole = LOLE{event_length,L,T}(
            MeanEstimate(sum(val.(LOLE.(sf,event_timestamps))))
            )

    system_eue = EUE{event_length,L,T,E}(
            MeanEstimate(sum(val.(EUE.(sf,event_timestamps))))
            )

    system_neue = NEUE(
            div(MeanEstimate(sum(val.(EUE.(sf,event_timestamps)))),
                sum(sf.regions.load[:,ts_first:ts_last])/1e6))

    lole = LOLE{event_length,L,T}[]
    eue = EUE{event_length,L,T,E}[]
    neue = NEUE[]
    
    if length(sf.regions) > 1
        region_names = ["System"]

        for (r,region) in enumerate(sf.regions.names)

            push!(lole,
                LOLE{event_length,L,T}(
                MeanEstimate(sum(val.(LOLE.(sf,region,event_timestamps))))
                )
            )

            push!(eue,
                EUE{event_length,L,T,E}(
                    MeanEstimate(sum(val.(EUE.(sf,region,event_timestamps))))
                    )
                )

            push!(neue,
                NEUE(
                    div(MeanEstimate(sum(val.(EUE.(sf,region,event_timestamps)))),
                        sum(sf.regions.load[r,ts_first:ts_last])/1e6))
                )
            
            push!(region_names,region)
        end
    end

    return Event(name,event_timestamps,
                system_lole, system_eue, system_neue,
                lole,eue,neue,
                sf.regions.names)
end

"""
    get_events(sf::ShortfallResult{N,L,T,E}, event_threshold=0) where {N,L,T,E}

Extracts events from PRAS ShortfallResult objects where an event is a contiguous 
period during which the system EUE exceeds a specified threshold, and 
returns a vector of (@ref Event) objects.

If the PRAS simulation is hourly and event_threshold is 0, and there are 
5 consecutive hours where the system EUE exceeds the threshold, this returns a 
vector with a single event. 
"""
function get_events(sf::ShortfallResult{N,L,T,E}, event_threshold=0) where {N,L,T,E}
    
    event_threshold < 0 && error("Event threshold must be non-negative")

    eue_system = EUE.(sf,sf.timestamps)
    system_eue_above_threshold = findall(val.(eue_system) .> event_threshold)

    isempty(system_eue_above_threshold) && error("No shortfall events in this simulation")

    event_timegroups = get_stepranges(sf.timestamps[system_eue_above_threshold],L,T)        
    
    return map(ts_group -> Event(sf,ts_group,
                            format(first(ts_group),"yyyy-mm-dd HH:MM ZZZ")
                            ),
                event_timegroups)
                    
end

function get_stepranges(vec::Vector{ZonedDateTime},L,T)
    groups = Vector{StepRange{ZonedDateTime,T}}()
    start = vec[1]
    final = vec[1]
    for next in vec[2:end]
        if next == final + T(L)
            final = next
        else
            push!(groups, StepRange(start,T(L),final))
            start = next
            final = next
        end
    end
    push!(groups, StepRange(start,T(L),final))
    return groups
end