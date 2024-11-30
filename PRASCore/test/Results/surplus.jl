@testset "SurplusResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    result = PRASCore.Results.SurplusResult{N,1,Hour,MW}(
        DD.nsamples, DD.resourcenames, DD.periods,
        DD.d1_resourceperiod, DD.d2_period, DD.d2_resourceperiod)

    # Period-specific

    @test result[t] ≈ (sum(DD.d1_resourceperiod[:, t_idx]), DD.d2_period[t_idx])
    @test_throws BoundsError result[t_bad]

    # Region + period-specific

    @test result[r, t] ≈
              (DD.d1_resourceperiod[r_idx, t_idx], DD.d2_resourceperiod[r_idx, t_idx])

    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

end

@testset "SurplusSamplesResult" begin

    N = DD.nperiods
    r, r_idx, r_bad = DD.testresource, DD.testresource_idx, DD.notaresource
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    result = PRASCore.Results.SurplusSamplesResult{N,1,Hour,MW}(
        DD.resourcenames, DD.periods, DD.d)

    # Period-specific

    @test length(result[t]) == DD.nsamples
    @test result[t] ≈ vec(sum(view(DD.d, :, t_idx, :), dims=1))
    @test_throws BoundsError result[t_bad]

    # Region + period-specific

    @test length(result[r, t]) == DD.nsamples
    @test result[r, t] ≈ vec(DD.d[r_idx, t_idx, :])
    @test_throws BoundsError result[r, t_bad]
    @test_throws BoundsError result[r_bad, t]
    @test_throws BoundsError result[r_bad, t_bad]

end
