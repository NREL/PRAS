using PRAS
using PRASReport

rts_sys = rts_gmlc();
rts_sys.regions.load .+= 375;

sf, = assess(rts_sys,SequentialMonteCarlo(samples=100),Shortfall());

event_threshold = 0
events = get_events(sf,event_threshold)

println("System $(EUE(sf))")
println("System $(NEUE(sf))")
println("Number of events where each event-hour in the event has EUE > $event_threshold MW: ", length(events))
println("Longest event is over a period of ", maximum(event_length.(events)))

