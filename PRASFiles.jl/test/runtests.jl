using PRASCore
using PRASFiles
using Test
using JSON3

@testset "PRASFiles" begin

    @testset "Roundtrip .pras files to/from disk" begin

        # TODO: Verify systems accurately depicted?
        path = dirname(@__FILE__)

        toy = PRASFiles.toymodel()
        savemodel(toy, path * "/toymodel2.pras")
        toy2 = SystemModel(path * "/toymodel2.pras")
        @test toy == toy2

        rts = PRASFiles.rts_gmlc()
        savemodel(rts, path * "/rts2.pras")
        rts2 = SystemModel(path * "/rts2.pras")
        @test rts == rts2

    end

    @testset "Run RTS-GMLC" begin

        assess(PRASFiles.rts_gmlc(), SequentialMonteCarlo(samples=100), Shortfall())

    end

    @testset "Save Aggregate Results" begin
        rts_sys = PRASFiles.rts_gmlc()
        # Make load in all regions in rts_sys 10 times the original load for meaningful results
        for i in 1:length(rts_sys.regions.names)
            rts_sys.regions.load[i, :] = 10 * rts_sys.regions.load[i, :]
        end
        results = assess(rts_sys, SequentialMonteCarlo(samples=10, threaded = false, seed = 1), Shortfall());
        shortfall = results[1];
        path = joinpath(dirname(@__FILE__),"PRAS_Results_Export");
        exp_location = PRASFiles.saveshortfall(shortfall, rts_sys, path);
        @test isfile(joinpath(exp_location, "pras_results.json"))
        exp_results = JSON3.read(joinpath(exp_location, "pras_results.json"), PRASFiles.SystemResult)
        @test exp_results.lole.mean == PRASCore.LOLE(shortfall).lole.estimate
        @test exp_results.eue.mean == PRASCore.EUE(shortfall).eue.estimate
        @test exp_results.neue.mean == PRASCore.NEUE(shortfall).neue.estimate
        @test exp_results.region_results[1].lole.mean == PRASCore.LOLE(shortfall, exp_results.region_results[1].name).lole.estimate
        @test exp_results.region_results[1].eue.mean == PRASCore.EUE(shortfall, exp_results.region_results[1].name).eue.estimate
        @test exp_results.region_results[1].neue.mean == PRASCore.NEUE(shortfall, exp_results.region_results[1].name).neue.estimate
    end

end
