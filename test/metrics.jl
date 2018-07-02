@testset "Metrics" begin

    @testset "LOLP" begin

        lolp1 = LOLP{1,Hour}(.1, 0.)
        lolp2 = LOLP{2,Day}(.12, 0.04)

        @test_throws ErrorException LOLP{1,Hour}(1.2, 0.)
        @test_throws ErrorException LOLP{1,Hour}(.2, -1.)
        @test_throws ErrorException LOLP{1,Hour}(-.3, 0.)

    end


    @testset "LOLE" begin

        lole1 = LOLE{2,Hour,1,Year}(2.4,0.)
        lole1 = LOLE{1,Hour,8760,Hour}(2.4,0.)
        lole2 = LOLE{1,Day,10,Year}(1.0,0.01)
        lole3 = LOLE(LOLP{1,Hour}.(rand(168)/10, rand(168)/100))
        @test_throws ErrorException LOLE{1,Day,10,Year}(-1.2, 0.)
        @test_throws ErrorException LOLE{1,Day,10,Year}(1.2, -0.2)

    end


    @testset "EUE" begin

        eue1 = EUE{MWh,1,Hour}(1.2, 0.)
        eue2 = EUE{GWh,2,Year}(17.2, 1.3)
        eues1 = EUE{MWh,1,Hour}.(rand(168), 0.)
        eue3 = EUE(eues1)
        @test_throws ErrorException EUE{MWh,1,Hour}(-1.2, 0.)
        @test_throws ErrorException EUE{MWh,1,Hour}(1.2, -0.1)

    end

end
