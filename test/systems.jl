# Components

## Generator Data
gens1 = reshape(RA.DispatchableGeneratorSpec.(
    [10., 10. , 10.], [0.1, 0.1, 0.1], [0.9, 0.9, 0.9]), 3, 1)
gens2 = reshape(RA.DispatchableGeneratorSpec.(
    [10., 20. , 15., 25], [0.1, 0.1, 0.1, 0.1], [0.9, 0.9, 0.9, 0.9]), 2, 2)

## Storage device data
#TODO: Create and test a system with storage
stors1 = Matrix{RA.StorageDeviceSpec{Float64}}(0,1)
storages1 = [ResourceAdequacy.StorageDeviceSpec(1., 4., 0.99, 0., 1.0)]
storages2 = [ResourceAdequacy.StorageDeviceSpec(1., 4., 0.99, 0.05, 0.5)]

## Line data
lines1 = [ResourceAdequacy.LineSpec(10., 0.004, 0.04),
         ResourceAdequacy.LineSpec(10., 0.017, 0.04),
         ResourceAdequacy.LineSpec(10., 0.017, 0.04)]

lines2 = [ResourceAdequacy.LineSpec(8., 0., 1.),
         ResourceAdequacy.LineSpec(8., 0., 1.),
         ResourceAdequacy.LineSpec(8., 0., 1.)]

# Systems

## Single-Region System A
singlenode_a = ResourceAdequacy.SystemModel{4,1,Hour,MW,MWh}(
    gens1, stors1, DateTime(2010,1,1):Hour(1):DateTime(2010,1,1,3),
    ones(Int, 4), ones(Int, 4), [5., 6, 7, 8], [25., 28, 27, 24])

## Single-Region System B
singlenode_b = ResourceAdequacy.SystemModel{6,1,Hour,MW,MWh}(
    gens2, stors1, DateTime(2015,6,1):Hour(1):DateTime(2015,6,1,5),
    [1,1,1,2,2,2], ones(Int, 6), [7.,8,9,9,8,7], [28.,29,30,31,32,33])

## Multi-Region System

threenode =
    ResourceAdequacy.SystemModel{4,1,Hour,MW,MWh}(
        ["Region A", "Region B", "Region C"],
        [gens1 gens1; gens2], [1,2,4],
        stors1, [1,1,1],
        [(1,2), (1,3), (2,3)], hcat(lines2), [1,2,3],
        DateTime(2018,10,30,0):Hour(1):DateTime(2018,10,30,3),
        [1, 1, 2, 1], ones(Int, 4), ones(Int, 4), # Time set references
        [4. 3 2 3; 6 5 3 4; 2 1 2 1], # VG
        [19. 20 21 20; 20 21 21 22; 22 21 23 22] # Load
)

