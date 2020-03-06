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

singlenode_a = SystemModel(
    gens1, emptystors1, emptygenstors1,
    DateTime(2010,1,1,0):Hour(1):DateTime(2010,1,1,3),
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

singlenode_a_5min = ResourceAdequacy.SystemModel{4,5,Minute,MW,MWh}(
    gens1_5min, emptystors1_5min, emptygenstors1_5min,
    DateTime(2010,1,1,0,0):Minute(5):DateTime(2010,1,1,0,15),
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

genstors2 = GeneratorStorages{6,1,Hour,MW,MWh}(
    ["Genstor1", "Genstor2"], ["Genstorage", "Genstorage"],
    fill(0, 2, 6), fill(0, 2, 6), fill(4, 2, 6),
    fill(1.0, 2, 6), fill(1.0, 2, 6), fill(.99, 2, 6),
    fill(0, 2, 6), fill(0, 2, 6), fill(0, 2, 6),
    fill(0.0, 2, 6), fill(1.0, 2, 6))

singlenode_b = SystemModel(
    gens2, emptystors2, emptygenstors2,
    DateTime(2015,6,1,0):Hour(1):DateTime(2015,6,1,5),
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
    gens2, stors2, genstors2,
    DateTime(2015,6,1,0):Hour(1):DateTime(2015,6,1,5),
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
        lines, [1:1, 2:2, 3:3],
        DateTime(2018,10,30,0):Hour(1):DateTime(2018,10,30,3))

threenode_lole = 1.3756
threenode_lolps = [0.14707, 0.40951, 0.40951, 0.40951]
threenode_eue = 12.12885
threenode_eues = [1.75783, 3.13343, 2.87563, 4.36196]

threenode_lole_copperplate = 1.17877
threenode_lolps_copperplate = [.14707, .40951, .21268, .40951]
threenode_eue_copperplate = 11.73276
threenode_eues_copperplate = [1.75783, 3.13343, 2.47954, 4.36196]
