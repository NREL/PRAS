mutable struct Event{N,L,T,E}
    name::String
    timestamps::StepRange{ZonedDateTime,T}
    lole::Vector{LOLE}
    eue::Vector{EUE}
    neue::Vector{NEUE}
    regions::Vector{String}

    function Event{}(name::String, timestamps::StepRange{ZonedDateTime,T}, 
                     lole::Vector{LOLE{N,L,T}}, eue::Vector{EUE{N,L,T,E}}, 
                     neue::Vector{NEUE}, regions::Vector{String}
                    ) where {N,L,T,E}

        length(lole) != length(eue) != length(neue) != length(regions) && 
            error("Length of lole, eue, neue, and region names vectors must be equal")

        length(timestamps) != N &&
            error("Number of timesteps should match metrics event length")

        length(regions) > 1 && !isapprox(val(eue[1]),sum(val.(eue[2:end]))) &&
            error("First value in an event eue array should represent system EUE" 
                    *"which is approximately the sum of EUE of all the regions")

        new{N,L,T,E}(name, timestamps, lole, eue, neue, regions)
    end
end

mutable struct sf_ts{}
    name::String
    timestamps::Vector{ZonedDateTime}
    eue::Vector{Vector{EUE}}
    lole::Vector{Vector{LOLE}}
    neue::Vector{Vector{NEUE}}
    regions::Vector{String}

    function sf_ts(event,sf{N,L,T,E}) where {N,L,T,E}
        name = event.name
        timestamps = collect(event.timestamps)
        eue = EUE{1,L,T,E}(MeanEstimate(val.(EUE.(sf,:,timestamps)))) 
        lole = LOLE{1,L,T}(MeanEstimate(val.(LOLE.(sf,:,timestamps)))) 
        neue = NEUE(MeanEstimate(val.(NEUE.(sf,:,timestamps)))) 
        regions = event.regions[2:end]
        new(name,timestamps,[eue],[lole],[neue],regions)
    end
end

mutable struct flow_ts{}
    name::String
    timestamps::Vector{ZonedDateTime}
    flow::Vector{Vector{NEUE}}
    interfaces::Vector{String}
    function flow_ts(timestamps::Vector{ZonedDateTime})
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



    lole = [LOLE{event_length,L,T}(
            MeanEstimate(sum(val.(LOLE.(sf,event_timestamps))))
            )]

    eue = [EUE{event_length,L,T,E}(
            MeanEstimate(sum(val.(EUE.(sf,event_timestamps))))
            )]

    neue = [NEUE(
            div(MeanEstimate(sum(val.(EUE.(sf,event_timestamps)))),
                sum(sf.regions.load[:,ts_first:ts_last])/1e6))]
    
    if length(sf.regions) == 1
        # TODO: Change variable name
        # TODO: Should all events have common region_names?
        region_names = sf.regions.names
    else
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

    return Event(name,event_timestamps,lole,eue,neue,region_names)
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