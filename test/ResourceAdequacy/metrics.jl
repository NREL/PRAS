@testset "Metrics" begin

    @testset "LOLP" begin

        lolp1 = LOLP{1,Hour}(.1, 0.)
        lolp2 = LOLP{2,Day}(.12, 0.04)

        @test_throws ErrorException LOLP{1,Hour}(1.2, 0.)
        @test_throws ErrorException LOLP{1,Hour}(.2, -1.)
        @test_throws ErrorException LOLP{1,Hour}(-.3, 0.)

    end


    @testset "LOLE" begin

        lole1 = LOLE{4380,2,Hour}(2.4,0.)
        lole1 = LOLE{8760,1,Hour}(2.4,0.)
        lole2 = LOLE{3650,1,Day}(1.0,0.01)
        @test_throws ErrorException LOLE{3650,1,Day}(-1.2, 0.)
        @test_throws ErrorException LOLE{3650,1,Day}(1.2, -0.2)

    end


    @testset "EUE" begin

        eue1 = EUE{2,1,Hour,MWh}(1.2, 0.)
        eue2 = EUE{1,2,Year,GWh}(17.2, 1.3)
        eues1 = EUE{1,1,Hour,MWh}.(rand(168), 0.)
        @test_throws ErrorException EUE{1,1,Hour,MWh}(-1.2, 0.)
        @test_throws ErrorException EUE{1,1,Hour,MWh}(1.2, -0.1)

    end

    @testset "ExpectedInterfaceFlow" begin

        eue1 = ExpectedInterfaceFlow{1,1,Hour,MW}(1.2, 0.)
        eue2 = ExpectedInterfaceFlow{1,1,Hour,MW}(-1.2, 0.1)
        eue3 = ExpectedInterfaceFlow{1,2,Year,GW}(17.2, 1.3)
        eues1 = ExpectedInterfaceFlow{1,1,Hour,MW}.(rand(168), 0.)
        @test_throws ErrorException ExpectedInterfaceFlow{1,1,Hour,MW}(1.2, -0.1)

    end

    @testset "ExpectedInterfaceUtilization" begin

        eue1 = ExpectedInterfaceUtilization{1,1,Hour}(0.95, 0.)
        eue2 = ExpectedInterfaceUtilization{1,1,Hour}(0.9, 0.1)
        eue3 = ExpectedInterfaceUtilization{1,2,Year}(0.4, 1.3)
        eues1 = ExpectedInterfaceUtilization{1,1,Hour}.(rand(168), 0.)
        @test_throws ErrorException ExpectedInterfaceUtilization{1,1,Hour}(1.2, 0.1)
        @test_throws ErrorException ExpectedInterfaceUtilization{1,1,Hour}(-0.2, 0.1)
        @test_throws ErrorException ExpectedInterfaceUtilization{1,1,Hour}(0.8, -0.1)

    end

end
