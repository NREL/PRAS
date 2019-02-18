# Components

## Generator Data
gens1 = reshape(RA.DispatchableGeneratorSpec.(
    [10., 10. , 10.], [0.1, 0.1, 0.1], [0.9, 0.9, 0.9]), 3, 1)
gens2 = reshape(RA.DispatchableGeneratorSpec.(
    [10., 20. , 15., 25], [0.1, 0.1, 0.1, 0.1], [0.9, 0.9, 0.9, 0.9]), 2, 2)

## Storage device data
#TODO: Create and test a system with storage
stors1 = Matrix{RA.StorageDeviceSpec{Float64}}(undef, 0,1)
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

singlenode_a_lole = 0.355
singlenode_a_lolps = [0.028, 0.271, 0.028, 0.028]
singlenode_a_eue = 1.59
singlenode_a_eues = [0.29, 0.832, 0.29, 0.178]

## Single-Region System B
singlenode_b = ResourceAdequacy.SystemModel{6,1,Hour,MW,MWh}(
    gens2, stors1, DateTime(2015,6,1):Hour(1):DateTime(2015,6,1,5),
    [1,1,1,2,2,2], ones(Int, 6), [7.,8,9,9,8,7], [28.,29,30,31,32,33])

singlenode_b_lole = 0.96
singlenode_b_lolps = [0.19, 0.19, 0.19, 0.1, 0.1, 0.19]
singlenode_b_eue = 7.11
singlenode_b_eues = [1.29, 1.29, 1.29, 0.85, 1.05, 1.34]

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

threenode_lole = 1.3756
threenode_lolps = [0.14707, 0.40951, 0.40951, 0.40951]
threenode_eue = 12.12885
threenode_eues = [1.75783, 3.13343, 2.87563, 4.36196]

threenode_lole_copperplate = 1.17877
threenode_lolps_copperplate = [.14707, .40951, .21268, .40951]
threenode_eue_copperplate = 11.73276
threenode_eues_copperplate = [1.75783, 3.13343, 2.47954, 4.36196]
