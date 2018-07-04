@testset "NetworkResult" begin

    nodelabels = ["A", "B", "C"]
    edgelabels = [(1,2), (1,3), (2,3)]

    nodes1 = [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,10.,x,x)
                 for x in [8., 10, 12]]
    edges1 = [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., 1.) for _ in 1:3]

    nodes2 = [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,10.,x,y)
                 for (x,y) in zip([9.,11,13], [9.,11,10])]
    edges2 = [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., x)
                 for x in [1., 0, 0]]

    nodes3 = [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10., x, x, x)
                 for x in [8., 9, 10]]
    edges3 = [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., 0.)
             for _ in 1:3]

    nodes4 = [ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(4.,4.,7.,6.),
              ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,9.,8.,8.),
              ResourceAdequacy.NodeResult{1,Hour,MW,MWh}(10.,10.,9.,9.)]
    edges4 = [ResourceAdequacy.EdgeResult{1,Hour,MW,MWh}(1., x)
              for x in [-1., 0, -1]]

    # States 1,2,3
    lolp1 = LOLP{1,Hour}(1/3, √(2/27))
    eue1  = EUE{MWh,1,Hour}(1.,  √(2/3))

    # States 2,3,4
    lolp2 = LOLP{1,Hour}(2/3, √(2/27))
    eue2  = EUE{MWh,1,Hour}(4/3, √42/9)

    # States 3,4,1
    lolp3 = LOLP{1,Hour}(1/3, √(2/27))
    eue3  = EUE{MWh,1,Hour}(1/3, √6/9)

    # Combining the above
    loletotal = LOLE{1,Hour,3,Hour}(4/3, √(2)/3)
    euetotal  = EUE{MWh,3,Hour}(8/3, √102/9)

    simspec = NonSequentialNetworkFlow(3)
    extrspec = Backcast()

    @testset "NetworkState" begin

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

        @test ns1.nodes == nodes1
        @test ns1.edges == edges1
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

        @test ns2.nodes == nodes2
        @test ns2.edges == edges2
        @test ResourceAdequacy.droppedload(ns2) ≈ 3.

        ns3 = ResourceAdequacy.NetworkState(
            nodes3, edges3, edgelabels)

        @test ResourceAdequacy.droppedload(ns3) == 0.

        nss = ResourceAdequacy.NetworkStateSet([ns1, ns2, ns3])

        @test LOLP(nss) ≈ lolp1
        @test LOLP(ResourceAdequacy.NetworkStateSet([ns2]), 3) ≈ lolp1

        @test EUE(nss) ≈ eue1
        @test EUE(ResourceAdequacy.NetworkStateSet([ns2]), 3) ≈ eue1

    end

    spr1 = ResourceAdequacy.SinglePeriodNetworkResult(
        nodelabels, edgelabels,
        hcat(nodes1, nodes2, nodes3), hcat(edges1, edges2, edges3),
        simspec, false)

    spr2 = ResourceAdequacy.SinglePeriodNetworkResult(
        nodelabels, edgelabels, reshape(nodes2, :, 1), reshape(edges2, :, 1),
        simspec, true)


    @testset "Single Period" begin

        @test LOLP(spr1) ≈ lolp1
        @test EUE(spr1) ≈ eue1


        @test LOLP(spr2) ≈ lolp1
        @test EUE(spr2) ≈ eue1

    end

    @testset "Multi Period" begin

        tstamps = collect(DateTime(1993,1,1,3):Hour(1):DateTime(1993,1,1,5))

        mpr1 = ResourceAdequacy.MultiPeriodNetworkResult(
            tstamps, nodelabels, edgelabels,
            [hcat(nodes1, nodes2, nodes3), hcat(nodes2, nodes3, nodes4),
             hcat(nodes3, nodes4, nodes1)],
            [hcat(edges1, edges2, edges3), hcat(edges2, edges3, edges4),
             hcat(edges3, edges4, edges1)],
            extrspec, simspec, false)

        @test timestamps(mpr1) == tstamps

        x = mpr1[tstamps[1]]
        y = spr1
        # @test mpr1[tstamps[1]] == spr1
        @test typeof(x) == typeof(y)
        @test x.nodelabels == y.nodelabels
        @test x.edgelabels == y.edgelabels
        @test x.nodesset == y.nodesset
        @test x.simulationspec == y.simulationspec
        @test x.failuresonly == y.failuresonly

        @test LOLP(mpr1[tstamps[1]]) ≈ lolp1
        @test EUE(mpr1[tstamps[1]]) ≈ eue1
        @test LOLP(mpr1[tstamps[2]]) ≈ lolp2
        @test EUE(mpr1[tstamps[2]]) ≈ eue2
        @test LOLP(mpr1[tstamps[3]]) ≈ lolp3
        @test EUE(mpr1[tstamps[3]]) ≈ eue3
        @test LOLE(mpr1) ≈ loletotal
        @test EUE(mpr1) ≈ euetotal

        @test_throws BoundsError mpr1[tstamps[1] - Hour(1)]

        mpr2 = ResourceAdequacy.MultiPeriodNetworkResult(
            tstamps, nodelabels, edgelabels,
            [hcat(nodes2), hcat(nodes2, nodes4), hcat(nodes4)],
            [hcat(edges2), hcat(edges2, edges4), hcat(edges4)],
            extrspec, simspec, true)

        @test LOLE(mpr2) ≈ loletotal
        @test EUE(mpr2) ≈ euetotal
        # @test mpr2[tstamps[1]] == spr2
        x = mpr2[tstamps[1]]
        y = spr2
        @test typeof(x) == typeof(y)
        @test x.nodelabels == y.nodelabels
        @test x.edgelabels == y.edgelabels
        @test x.nodesset == y.nodesset
        @test x.simulationspec == y.simulationspec
        @test x.failuresonly == y.failuresonly

    end

end
