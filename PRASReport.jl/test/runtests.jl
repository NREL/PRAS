using Test
using PRASReport
using TimeZones
using Dates

# Test copperplate
# Test get functions from database for wrong names

@testset "PRASReport.jl Tests" begin
    @testset "Test events" begin
        
        eue = [EUE{2,1,Hour,MWh}(MeanEstimate(1.2)), 
               EUE{2,1,Hour,MWh}(MeanEstimate(0.6)),
               EUE{2,1,Hour,MWh}(MeanEstimate(0.5)),
               EUE{2,1,Hour,MWh}(MeanEstimate(0.1)),
        ]

        lole = [LOLE{4380,2,Hour}(MeanEstimate(0.13)),
                LOLE{4380,2,Hour}(MeanEstimate(0.08)),
                LOLE{4380,2,Hour}(MeanEstimate(0.06)),
                LOLE{4380,2,Hour}(MeanEstimate(0.04))

        ]

        @test event_length(event) == Hour(5)
    end

    @testset "Test get_events" begin
        
        #TODO: Test for empty sf object

    end
    @testset "Test get_stepranges" begin

        timestamps = ZonedDateTime.(DateTime(2023,1,1):Hour(1):DateTime(2023,1,10), tz"UTC")
        selected_times = [timestamps[2], timestamps[3], timestamps[5], timestamps[6], timestamps[7], timestamps[9]]
        step_ranges = get_stepranges(selected_times, Hour(1), Hour(1))

        @test length(step_ranges) == 3 "Incorrect number of step ranges"
        @test step_ranges[1] == (timestamps[2]:Hour(1):timestamps[3]) "First step range incorrect"
        @test step_ranges[2] == (timestamps[5]:Hour(1):timestamps[7]) "Second step range incorrect"
        @test step_ranges[3] == (timestamps[9]:Hour(1):timestamps[9]) "Third step range incorrect"
    end
end
