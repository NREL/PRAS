mutable struct Event{N,L,T,E}
    name::String
    timestamps::StepRange{ZonedDateTime,T}
    lole::Vector{LOLE}
    eue::Vector{EUE}
    neue::Vector{NEUE}
    regions::Vector{String}

    function Event{}(name::String, timestamps::StepRange{ZonedDateTime,T}, lole::Vector{LOLE{N,L,T}}, eue::Vector{EUE{N,L,T,E}}, neue::Vector{NEUE}, regions::Vector{String}) where {N,L,T,E}
        @assert length(lole) == length(eue) == length(neue) "Length of lole, eue, and neue vectors must be equal"
        new{N,L,T,E}(name, timestamps, lole, eue, neue, regions)
    end
end

Base.length(event::Event{N,L,T}) where {N,L,T} = T(N*L)

function get_events(sf::ShortfallResult{N,L,T,E}, event_threshold=0) where {N,L,T,E}
    
    eue_system = EUE.(sf,sf.timestamps)
    system_eue_above_threshold = findall(val.(eue_system) .> event_threshold)
    event_timegroups = get_stepranges(sf.timestamps[system_eue_above_threshold],L,T)        
    
    return map(ts_group -> Event(sf,ts_group,
                            format(first(ts_group),"yyyy-mm-dd HH:MM ZZZ")
                            ),
                event_timegroups)
                    
end

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

    lole = Vector{LOLE{event_length,L,T}}()
    eue = Vector{EUE{event_length,L,T,E}}()
    neue = Vector{NEUE}()
    push!(lole,
          LOLE{event_length,L,T}(
            MeanEstimate(sum(val.(LOLE.(sf,event_timestamps))))
            )
        )
    push!(eue,
          EUE{event_length,L,T,E}(
            MeanEstimate(sum(val.(EUE.(sf,event_timestamps))))
            )
        )

    push!(neue,
          NEUE(
            div(MeanEstimate(sum(val.(EUE.(sf,event_timestamps)))),
                sum(sf.regions.load[:,ts_first:ts_last])/1e6))
        )
    
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
    end

    # TODO: Change variable name
    # TODO: Should all events have common region_names?
    region_names = ["System",sf.regions.names...]

    return Event(name,event_timestamps,lole,eue,neue,region_names)
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