using Test
using Dates
using PRASReport
using PRASCore
using PRASFiles
using TimeZones
using Suppressor
using DuckDB
using Tables
using Base64: base64decode

# Test copperplate
# Test get functions from database for wrong names
system = rts_gmlc()

@testset "PRASReport.jl Tests" begin
    @testset "Test events" begin
        include("events.jl")
    end

    @testset "Test html report generation" begin

        include("report.jl")

    end
end
