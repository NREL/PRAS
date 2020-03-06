"""

    SystemModel(filename::String)

Load a `SystemModel` from an appropriately-formatted HDF5 file on disk.
"""
function SystemModel(inputfile::String)

    system = h5open(inputfile, "r") do f::HDF5File

        version, versionstring = readversion(f)
        println("$versionstring = $version")

        # Determine the appropriate version of the constructor to use 
        return if (0,2,0) <= version < (0,3,0)
            systemmodel_0_2(f)
        else
            @error("File format $versionstring not supported by this version of PRASBase.")
        end

    end

    return system

end


function systemmodel_0_2(f::HDF5File)

    metadata = attrs(f)

    start_timestamp = ZonedDateTime(read(metadata["start_timestamp"]),
                                    dateformat"yyyy-mm-ddTHH:MM:SSz")

    N = read(metadata["timestep_count"])
    L = read(metadata["timestep_length"])
    T = timeunits[read(metadata["timestep_unit"])]
    P = powerunits[read(metadata["power_unit"])]
    E = energyunits[read(metadata["energy_unit"])]

    timestamps = range(start_timestamp, length=N, step=T(L))

    regionnames = readvector(f["regions/_core"], "name")
    regions = Regions{N,P}(
        regionnames,
        Int.(read(f["regions/load"]))
    )
    regionlookup = Dict(n=>i for (i, n) in enumerate(regionnames))

    # TODO: Some of these are optional

    generators = Generators{N,L,T,P}(
        readvector.(Ref(f["generators/_core"]), ["name", "category"])...,
        Int.(read(f["generators/capacity"])),
        read(f["generators/failureprobability"]),
        read(f["generators/repairprobability"])
    )

    storages = Storages{N,L,T,P,E}(
        readvector.(Ref(f["storages/_core"]), ["name", "category"])...,
        Int.(read(f["storages/chargecapacity"])),
        Int.(read(f["storages/dischargecapacity"])),
        Int.(read(f["storages/energycapacity"])),
        read(f["storages/chargeefficiency"]),
        read(f["storages/dischargeefficiency"]),
        read(f["storages/carryoverefficiency"]),
        read(f["storages/failureprobability"]),
        read(f["storages/repairprobability"])
    )
    generatorstorages = GeneratorStorages{N,L,T,P,E}(
        readvector.(Ref(f["generatorstorages/_core"]), ["name", "category"])...,
        Int.(read(f["generatorstorages/chargecapacity"])),
        Int.(read(f["generatorstorages/dischargecapacity"])),
        Int.(read(f["generatorstorages/energycapacity"])),
        read(f["generatorstorages/chargeefficiency"]),
        read(f["generatorstorages/dischargeefficiency"]),
        read(f["generatorstorages/carryoverefficiency"]),
        Int.(read(f["generatorstorages/inflow"])),
        Int.(read(f["generatorstorages/gridinjectioncapacity"])),
        Int.(read(f["generatorstorages/gridwithdrawalcapacity"])),
        read(f["generatorstorages/failureprobability"]),
        read(f["generatorstorages/repairprobability"])
    )

    from_regions, to_regions =
        readvector.(Ref(f["interfaces/_core"]), ["region1", "region2"])

    interfaces = Interfaces{N,P}(
        getindex.(Ref(regionlookup), from_regions),
        getindex.(Ref(regionlookup), to_regions),
        Int.(read(f["interfaces/forwardcapacity"])),
        Int.(read(f["interfaces/backwardcapacity"]))
    )

    lines = Lines{N,L,T,P}(
        readvector.(Ref(f["lines/_core"]), ["name", "category"])...,
        Int.(read(f["lines/forwardcapacity"])),
        Int.(read(f["lines/backwardcapacity"])),
        read(f["lines/failureprobability"]),
        read(f["lines/repairprobability"])
    )

    # TODO: Need to sort these by resource region!
    placeholders = fill(1:0, length(regions)-1)
    region_gen_idxs = push!(copy(placeholders), 1:length(generators))
    region_stor_idxs = push!(copy(placeholders), 1:length(storages))
    region_genstor_idxs = push!(copy(placeholders), 1:length(generatorstorages))
    interface_line_idxs = push!(copy(placeholders), 1:length(lines))

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        lines, interface_line_idxs,
        timestamps)

end

"""
Attempts to parse the file's "vX.Y.Z" version label into (x::Int, y::Int, z::Int).
Errors if the label cannot be found or parsed as expected.
"""
function readversion(f::HDF5File)

    exists(attrs(f), "pras_dataversion") || error(
          "File format version indicator could not be found - the file may " *
          "not be a PRAS SystemModel representation.")

    versionstring = read(attrs(f)["pras_dataversion"])

    version = match(r"^v(\d+)\.(\d+)\.(\d+)$", versionstring)
    isnothing(version) && error("File format version $versionstring not recognized")

    major, minor, patch = parse.(Int, version.captures)

    return (major, minor, patch), versionstring

end

"""
Attempts to extract a vector of elements from an HDF5 compound datatype,
corresponding to `field`.
"""
function readvector(d::HDF5Dataset, field::String)
    data = read(d)
    fieldorder = data[1].membername
    idx = findfirst(isequal(field), fieldorder)
    fieldtype = data[1].membertype[idx]
    return fieldtype.(getindex.(getfield.(data, :data), idx))
end
