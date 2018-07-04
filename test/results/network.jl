@testset "NetworkResult" begin

    @testset "NetworkState" begin

        edgelabels = [(1,2), (1,3), (2,3)]
        # All load served
        statematrix = [0. 1  1  0 8;
                       1  0  1  0 10;
                       1  1  0  0 12;
                       10 10 10 0 0;
                       0  0  0  0 0]
        flowmatrix = [0. 1  1  0 8;
                      -1 0  1  0 10;
                      -1 -1 0  0 12;
                      10 10 10 0 0;
                      0  0  0  0 0]

        ns1 = ResourceAdequacy.NetworkState{1,Hour,MW,MWh}(
            statematrix, flowmatrix,
            edgelabels, 3)

        @test ns1.nodes == [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,10.,x,x) for x in [8., 10, 12]]
        @test ns1.edges == [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., 1.) for _ in 1:3]
        @test ResourceAdequacy.droppedload(ns1) == 0.

        # Unserved load
        statematrix = [0. 1  1  0 9;
                       1  0  1  0 11;
                       1  1  0  0 13;
                       10 10 10 0 0;
                       0  0  0  0 0]
        flowmatrix = [0. 1  0  0 9;
                      -1 0  0  0 11;
                      0  0  0  0 10;
                      10 10 10 0 0;
                      0  0  0  0 0]

        ns2 = ResourceAdequacy.NetworkState{1,Hour,MW,MWh}(
            statematrix, flowmatrix,
            edgelabels, 3)

        @test ns2.nodes == [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,10.,x,y)
                            for (x,y) in zip([9.,11,13], [9.,11,10])]
        @test ns2.edges == [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., x)
                            for x in [1., 0, 0]]
        @test ResourceAdequacy.droppedload(ns2) ≈ 3.

        ns3 = ResourceAdequacy.NetworkState(
            [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10., x, x, x)
             for x in [8., 9, 10]],
            [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., 0.)
             for _ in 1:3], edgelabels)

        @test ResourceAdequacy.droppedload(ns3) == 0.

        nss = ResourceAdequacy.NetworkStateSet([ns1, ns2, ns3])

        @test LOLP(nss) ≈ LOLP{1,Hour}(1/3, sqrt(2/27))
        @test LOLP(ResourceAdequacy.NetworkStateSet([ns2]), 3) ≈
            LOLP{1,Hour}(1/3, sqrt(2/27))

        @test EUE(nss) ≈ EUE{MWh,1,Hour}(1., sqrt(2/3))
        @test EUE(ResourceAdequacy.NetworkStateSet([ns2]), 3) ≈
            EUE{MWh,1,Hour}(1., sqrt(2/3))

    end

    @testset "Single Period" begin
        #stuff
    end

    @testset "Multi Period" begin
        #stuff
    end

end
