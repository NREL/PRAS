module TestData

using ..Systems
using TimeZones

const tz = tz"UTC"

empty_str = String[]
empty_int(x) = Matrix{Int}(undef, 0, x)
empty_float(x) = Matrix{Float64}(undef, 0, x)

## Single-Region System A

gens1 = Generators{4,1,Hour,MW}(
    ["Gen1", "Gen2", "Gen3", "VG"], ["Gens", "Gens", "Gens", "VG"],
    [fill(10, 3, 4); [5 6 7 8]],
    [fill(0.1, 3, 4); fill(0.0, 1, 4)],
    [fill(0.9, 3, 4); fill(1.0, 1, 4)])

emptystors1 = Storages{4,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
                  (empty_int(4) for _ in 1:3)...,
                  (empty_float(4) for _ in 1:5)...)

emptygenstors1 = GeneratorStorages{4,1,Hour,MW,MWh}(
    (empty_str for _ in 1:2)...,
    (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:3)...,
    (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:2)...)

emptydrs1 = DemandResponses{4,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
    (empty_int(4) for _ in 1:3)...,
    (empty_float(4) for _ in 1:3)...,
    (empty_int(4) for _ in 1:1)...,
    (empty_float(4) for _ in 1:2)...)

singlenode_a = SystemModel(
    gens1, emptystors1, emptygenstors1,emptydrs1,
    ZonedDateTime(2010,1,1,0,tz):Hour(1):ZonedDateTime(2010,1,1,3,tz),
    [25, 28, 27, 24])

singlenode_a_lole = 0.355
singlenode_a_lolps = [0.028, 0.271, 0.028, 0.028]
singlenode_a_eue = 1.59
singlenode_a_eues = [0.29, 0.832, 0.29, 0.178]

## Single-Region System A - 5 minute version

gens1_5min = Generators{4,5,Minute,MW}(
    ["Gen1", "Gen2", "Gen3", "VG"], ["Gens", "Gens", "Gens", "VG"],
    [fill(10, 3, 4); [5 6 7 8]],
    [fill(0.1, 3, 4); fill(0.0, 1, 4)],
    [fill(0.9, 3, 4); fill(1.0, 1, 4)])

emptystors1_5min = Storages{4,5,Minute,MW,MWh}((empty_str for _ in 1:2)...,
                  (empty_int(4) for _ in 1:3)...,
                  (empty_float(4) for _ in 1:5)...)

emptygenstors1_5min = GeneratorStorages{4,5,Minute,MW,MWh}(
    (empty_str for _ in 1:2)...,
    (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:3)...,
    (empty_int(4) for _ in 1:3)..., (empty_float(4) for _ in 1:2)...)

emptydrs1_5min = DemandResponses{4,5,Minute,MW,MWh}((empty_str for _ in 1:2)...,
    (empty_int(4) for _ in 1:3)...,
    (empty_float(4) for _ in 1:3)...,
    (empty_int(4) for _ in 1:1)...,
    (empty_float(4) for _ in 1:2)...)

singlenode_a_5min = SystemModel(
    gens1_5min, emptystors1_5min, emptygenstors1_5min,emptydrs1_5min,
    ZonedDateTime(2010,1,1,0,0,tz):Minute(5):ZonedDateTime(2010,1,1,0,15,tz),
    [25, 28, 27, 24])

singlenode_a_lole = 0.355
singlenode_a_lolps = [0.028, 0.271, 0.028, 0.028]
singlenode_a_eue = 1.59
singlenode_a_eues = [0.29, 0.832, 0.29, 0.178]

## Single-Region System B

gens2 = Generators{6,1,Hour,MW}(
    ["Gen1", "Gen2", "VG"], ["Gens", "Gens", "VG"],
    [10 10 10 15 15 15; 20 20 20 25 25 25; 7 8 9 9 8 7],
    [fill(0.1, 2, 6); fill(0.0, 1, 6)],
    [fill(0.9, 2, 6); fill(1.0, 1, 6)])

emptystors2 = Storages{6,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
                  (empty_int(6) for _ in 1:3)...,
                  (empty_float(6) for _ in 1:5)...)

emptygenstors2 = GeneratorStorages{6,1,Hour,MW,MWh}(
    (empty_str for _ in 1:2)...,
    (empty_int(6) for _ in 1:3)..., (empty_float(6) for _ in 1:3)...,
    (empty_int(6) for _ in 1:3)..., (empty_float(6) for _ in 1:2)...)

emptydrs2 = DemandResponses{6,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
    (empty_int(6) for _ in 1:3)...,
    (empty_float(6) for _ in 1:3)...,
    (empty_int(6) for _ in 1:1)...,
    (empty_float(6) for _ in 1:2)...)

genstors2 = GeneratorStorages{6,1,Hour,MW,MWh}(
    ["Genstor1", "Genstor2"], ["Genstorage", "Genstorage"],
    fill(0, 2, 6), fill(0, 2, 6), fill(4, 2, 6),
    fill(1.0, 2, 6), fill(1.0, 2, 6), fill(.99, 2, 6),
    fill(0, 2, 6), fill(0, 2, 6), fill(0, 2, 6),
    fill(0.0, 2, 6), fill(1.0, 2, 6))

singlenode_b = SystemModel(
    gens2, emptystors2, emptygenstors2,emptydrs2,
    ZonedDateTime(2015,6,1,0,tz):Hour(1):ZonedDateTime(2015,6,1,5,tz),
    [28,29,30,31,32,33])

singlenode_b_lole = 0.96
singlenode_b_lolps = [0.19, 0.19, 0.19, 0.1, 0.1, 0.19]
singlenode_b_eue = 7.11
singlenode_b_eues = [1.29, 1.29, 1.29, 0.85, 1.05, 1.34]


# Single-Region System B, with storage
#TODO: Storage tests

stors2 = Storages{6,1,Hour,MW,MWh}(
    ["Stor1", "Stor2"], ["Storage", "Storage"],
    repeat([1,0], 1, 6), repeat([1,0], 1, 6), fill(4, 2, 6),
    fill(1.0, 2, 6), fill(1.0, 2, 6), fill(.99, 2, 6),
    fill(0.0, 2, 6), fill(1.0, 2, 6))

singlenode_stor = SystemModel(
    gens2, stors2, genstors2,emptydrs2,
    ZonedDateTime(2015,6,1,0,tz):Hour(1):ZonedDateTime(2015,6,1,5,tz),
    [28,29,30,31,32,33])


## Multi-Region System

regions = Regions{4,MW}(["Region A", "Region B", "Region C"],
                  [19 20 21 20; 20 21 21 22; 22 21 23 22])

generators = Generators{4,1,Hour,MW}(
    ["Gen1", "VG A", "Gen 2", "Gen 3", "VG B", "Gen 4", "Gen 5", "VG C"],
    ["Gens", "VG", "Gens", "Gens", "VG", "Gens", "Gens", "VG"],
    [10 10 10 10; 4 3 2 3;               # A
     10 10 10 10; 10 10 10 10; 6 5 3 4;  # B
     10 10 15 10; 20 20 25 20; 2 1 2 1], # C
    [fill(0.1, 1, 4); fill(0.0, 1, 4);  # A
     fill(0.1, 2, 4); fill(0.0, 1, 4);  # B
     fill(0.1, 2, 4); fill(0.0, 1, 4)], # C
    [fill(0.9, 1, 4); fill(1.0, 1, 4);  # A
     fill(0.9, 2, 4); fill(1.0, 1, 4);  # B
     fill(0.9, 2, 4); fill(1.0, 1, 4)]) # C)

interfaces = Interfaces{4,MW}(
    [1,1,2], [2,3,3], fill(100, 3, 4), fill(100, 3, 4))

lines = Lines{4,1,Hour,MW}(
    ["L1", "L2", "L3"], ["Lines", "Lines", "Lines"],
    fill(8, 3, 4), fill(8, 3, 4), fill(0., 3, 4), fill(1., 3, 4))

threenode =
    SystemModel(
        regions, interfaces, generators, [1:2, 3:5, 6:8],
        emptystors1, fill(1:0, 3), emptygenstors1, fill(1:0, 3),
        emptydrs1, fill(1:0, 3),
        lines, [1:1, 2:2, 3:3],
        ZonedDateTime(2018,10,30,0,tz):Hour(1):ZonedDateTime(2018,10,30,3,tz))

threenode_lole = 1.3756
threenode_lolps = [0.14707, 0.40951, 0.40951, 0.40951]
threenode_eue = 12.12885
threenode_eues = [1.75783, 3.13343, 2.87563, 4.36196]

threenode_lole_copperplate = 1.17877
threenode_lolps_copperplate = [.14707, .40951, .21268, .40951]
threenode_eue_copperplate = 11.73276
threenode_eues_copperplate = [1.75783, 3.13343, 2.47954, 4.36196]

# Test System 1 (2 Gens, 2 Regions)

regions = Regions{1, MW}(
    ["Region A", "Region B"], reshape([8, 9], 2, 1))

gens = Generators{1,1,Hour,MW}(
    ["Gen 1", "Gen 2"], ["Generators", "Generators"],
    fill(15, 2, 1), fill(0.1, 2, 1), fill(0.9, 2, 1))

emptystors = Storages{1,1,Hour,MW,MWh}((String[] for _ in 1:2)...,
                  (zeros(Int, 0, 1) for _ in 1:3)...,
                  (zeros(Float64, 0, 1) for _ in 1:5)...)

emptygenstors = GeneratorStorages{1,1,Hour,MW,MWh}(
    (String[] for _ in 1:2)...,
    (zeros(Int, 0, 1) for _ in 1:3)..., (zeros(Float64, 0, 1) for _ in 1:3)...,
    (zeros(Int, 0, 1) for _ in 1:3)..., (zeros(Float64, 0, 1) for _ in 1:2)...)

emptydrs= DemandResponses{1,1,Hour,MW,MWh}((String[] for _ in 1:2)...,
    (zeros(Int, 0, 1) for _ in 1:3)...,
    (zeros(Float64, 0, 1) for _ in 1:3)...,
    (zeros(Int, 0, 1) for _ in 1:1)...,
    (zeros(Float64, 0, 1) for _ in 1:2)...)

interfaces = Interfaces{1,MW}([1], [2], fill(8, 1, 1), fill(8, 1, 1))

lines = Lines{1,1,Hour,MW}(
    ["Line 1"], ["Lines"],
    fill(8, 1, 1), fill(8, 1, 1), fill(0.1, 1, 1), fill(0.9, 1, 1)
)

zdt = ZonedDateTime(2020,1,1,0, tz)
test1 = SystemModel(regions, interfaces,
    gens, [1:1, 2:2], emptystors, fill(1:0, 2), emptygenstors, fill(1:0, 2),emptydrs, fill(1:0, 2),
    lines, [1:1], zdt:Hour(1):zdt
)

test1_lole = .19
test1_loles = [.1, .1]

test1_eue = .647
test1_eues = [.314, .333]

test1_esurplus = 10.647
test1_esurpluses = [5.733, 4.914]

test1_i1_flow = 0.081
test1_i1_util = 0.231625

# Test System 2 (Gen + Stor, 1 Region)

timestamps = ZonedDateTime(2020,1,1,0, tz):Hour(1):ZonedDateTime(2020,1,1,1, tz)

gen = Generators{2,1,Hour,MW}(
    ["Gen 1"], ["Generators"],
    fill(10, 1, 2), fill(0.1, 1, 2), fill(0.9, 1, 2))

stor = Storages{2,1,Hour,MW,MWh}(
    ["Stor 1"], ["Storages"],
    fill(10, 1, 2), fill(10, 1, 2), fill(10, 1, 2),
    fill(1., 1, 2), fill(1., 1, 2), fill(1., 1, 2), fill(0.1, 1, 2), fill(0.9, 1, 2))

emptygenstors = GeneratorStorages{2,1,Hour,MW,MWh}(
    (String[] for _ in 1:2)...,
    (zeros(Int, 0, 2) for _ in 1:3)..., (zeros(Float64, 0, 2) for _ in 1:3)...,
    (zeros(Int, 0, 2) for _ in 1:3)..., (zeros(Float64, 0, 2) for _ in 1:2)...)

emptydrs2 = DemandResponses{2,1,Hour,MW,MWh}((empty_str for _ in 1:2)...,
    (empty_int(2) for _ in 1:3)...,
    (empty_float(2) for _ in 1:3)...,
    (empty_int(2) for _ in 1:1)...,
    (empty_float(2) for _ in 1:2)...)


test2 = SystemModel(gen, stor, emptygenstors,emptydrs2, timestamps, [8, 9])

test2_lole = 0.2
test2_lolps = [0.1, 0.1]

test2_eue = 1.5542
test2_eues = [0.8, 0.7542]

test2_esurplus = [0.18, 1.4022]

test2_eenergy = [1.62, 2.2842]

# Test System 3 (Gen + Stor, 2 Regions)

regions = Regions{2, MW}(["Region A", "Region B"], [8 9; 6 7])
gen = Generators{2,1,Hour,MW}(
    ["Gen 1"], ["Generators"],
    fill(25, 1, 2), fill(0.1, 1, 2), fill(0.9, 1, 2))

interfaces = Interfaces{2,MW}([1], [2], fill(15, 1, 2), fill(15, 1, 2))
line = Lines{2,1,Hour,MW}(
    ["Line 1"], ["Lines"],
    fill(15, 1, 2), fill(15, 1, 2), fill(0.1, 1, 2), fill(0.9, 1, 2)
)

test3 = SystemModel(regions, interfaces,
                    gen, [1:1, 2:1], stor, [1:0, 1:1],
                    emptygenstors, fill(1:0, 2),
                    emptydrs2, fill(1:0, 2),
                    line, [1:1], timestamps)

test3_lole = 0.320951
test3_lole_r = [0.2, 0.255341]
test3_lole_t = [0.19, 0.130951]
test3_lole_rt = [0.1 0.1; 0.19 0.065341]

test3_eue = 3.179289
test3_eue_t = [1.94, 1.239289]
test3_eue_r = [1.581902, 1.597387]
test3_eue_rt = [0.8 0.781902; 1.14 0.457387]

test3_esurplus_t = [3.879, 11.53228]
test3_esurplus_rt = [3.879 6.618087; 0. 4.914189]

test3_flow = 9.5424075
test3_flow_t = [11.421, 7.663815]

test3_util = 0.7440337
test3_util_t = [0.8614, 0.626674]

test3_eenergy = [6.561, 7.682202]


# Test System 4 (Gen + DR, 1 Region)

timestamps = ZonedDateTime(2020,1,1,1, tz):Hour(1):ZonedDateTime(2020,1,2,0, tz)

gen = Generators{24,1,Hour,MW}(
    ["Gen 1"], ["Generators"],
    fill(57, 1, 24), fill(0.00001, 1, 24), fill(0.9999, 1, 24))

emptystors = Storages{24,1,Hour,MW,MWh}(
    (String[] for _ in 1:2)...,
    (zeros(Int, 0, 24) for _ in 1:3)...,
    (zeros(Float64, 0, 24) for _ in 1:5)...)
    
emptygenstors = GeneratorStorages{24,1,Hour,MW,MWh}(
    (String[] for _ in 1:2)...,
    (zeros(Int, 0, 24) for _ in 1:3)..., (zeros(Float64, 0, 24) for _ in 1:3)...,
    (zeros(Int, 0, 24) for _ in 1:3)..., (zeros(Float64, 0, 24) for _ in 1:2)...)

dr = DemandResponses{24,1,Hour,MW,MWh}(
    ["DR1"], ["DemandResponses"],
    fill(10, 1, 24), fill(10, 1, 24), fill(10, 1, 24),
    fill(1., 1, 24), fill(1., 1, 24), fill(1., 1, 24),fill(6, 1, 24), fill(0.1, 1, 24), fill(0.9, 1, 24))


full_day_load_profile = [45,43,42,42,42,44,47,50,52,54,56,58,60,61,63,64,64,63,61,58,55,52,49,46]


test4= SystemModel(gen, emptystors, emptygenstors,dr, timestamps, full_day_load_profile)

test4_lole = 0.2
test4_lolps = [0.1, 0.1]

test4_eue = 1.5542
test4_eues = [0.8, 0.7542]

test4_esurplus = [0.18, 1.4022]

test4_eenergy = [1.62, 2.2842]

end
