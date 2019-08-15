@testset "Extraction" begin
    dts = DateTime(2001, 1, 1):Hour(1):DateTime(2001, 12, 31, 23)
    @test dts[RA.window_idxs(DateTime(2001, 1, 10), dts, 2, 0)] ==
        collect(DateTime(2001, 1, 9, 22):Hour(1):DateTime(2001, 1, 10, 2))

    @test dts[RA.window_idxs(DateTime(2001, 1, 10), dts, 2, 1)] ==
        vcat(collect(DateTime(2001, 1, 8, 22):Hour(1):DateTime(2001, 1, 9, 2)),
             collect(DateTime(2001, 1, 9, 22):Hour(1):DateTime(2001, 1, 10, 2)),
             collect(DateTime(2001, 1, 10, 22):Hour(1):DateTime(2001, 1, 11, 2)))
end
