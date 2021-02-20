@testset "UtilizationResult" begin

    N = DD.nperiods
    i, i_idx, i_bad = DD.testinterface, DD.testinterface_idx, DD.notaninterface
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    result = ResourceAdequacy.UtilizationResult{N,1,Hour}(
        DD.nsamples, DD.interfacenames, DD.periods,
        DD.d1_resourceperiod, DD.d2_resource, DD.d2_resourceperiod)

    # Interface-specific

    @test result[i] ≈ (mean(DD.d1_resourceperiod[i_idx, :]), DD.d2_resource[i_idx])
    @test_throws BoundsError result[i_bad]

    # Interface + period-specific

    @test result[i, t] ≈
              (DD.d1_resourceperiod[i_idx, t_idx], DD.d2_resourceperiod[i_idx, t_idx])

    @test_throws BoundsError result[i, t_bad]
    @test_throws BoundsError result[i_bad, t]
    @test_throws BoundsError result[i_bad, t_bad]

end

@testset "UtilizationSamplesResult" begin

    N = DD.nperiods
    i, i_idx, i_bad = DD.testinterface, DD.testinterface_idx, DD.notaninterface
    t, t_idx, t_bad = DD.testperiod, DD.testperiod_idx, DD.notaperiod

    result = ResourceAdequacy.UtilizationSamplesResult{N,1,Hour}(
        DD.interfacenames, DD.periods, DD.d)

    # Interface-specific

    @test length(result[i]) == DD.nsamples
    @test result[i] ≈ vec(mean(view(DD.d, i_idx, :, :), dims=1))
    @test_throws BoundsError result[i_bad]

    # Region + period-specific

    @test length(result[i, t]) == DD.nsamples
    @test result[i, t] ≈ vec(DD.d[i_idx, t_idx, :])
    @test_throws BoundsError result[i, t_bad]
    @test_throws BoundsError result[i_bad, t]
    @test_throws BoundsError result[i_bad, t_bad]

end
