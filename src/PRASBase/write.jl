"""
savemodel(sys::SystemModel, outfile::String) -> nothing

Export a PRAS SystemModel `sys` as a .pras file, saved to `outfile`
"""
function savemodel(
    sys::SystemModel, outfile::String;
    string_length::Int=64, compression_level::Int=1, verbose::Bool=false)

    verbose &&
        @info "The PRAS system being exported is of type $(typeof(pras_system))"

    h5open(outfile, "w") do f::File

        verbose && @info "Processing metadata for .pras file ..."
        process_metadata!(f, sys)

        verbose && @info "Processing Regions for .pras file ..."
        process_regions!(f, sys, string_length, compression_level)

        if verbose
            @info "The PRAS System being exported is a " *
                  (length(sys.regions) == 1 ? "single-node" : "zonal") *
                  " model."
        end

        if length(sys.generators) > 0
            verbose && @info "Processing Generators for .pras file ..."
            process_generators!(f, sys, string_length, compression_level)
        end

        if length(sys.storages) > 0
            verbose && @info "Processing Storages for .pras file ..."
            process_storages!(f, sys, string_length, compression_level)
        end

        if length(sys.generatorstorages) > 0
            verbose && @info "Processing GeneratorStorages for .pras file ..."
            process_generatorstorages!(f, sys, string_length, compression_level)
        end

        if length(sys.regions) > 1
            verbose && @info "Processing Lines and Interfaces for .pras file ..."
            process_lines_interfaces!(f, sys, string_length, compression_level)
        end

    end

    verbose && @info "Successfully exported the PRAS SystemModel to " *
                     ".pras file " * outfile

    return

end

function process_metadata!(
    f::File, sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}

    attrs = attributes(f)
    
    attrs["timestep_count"] = N
    attrs["timestep_length"] = L
    attrs["timestep_unit"] = unitsymbol(T)
    attrs["power_unit"] = unitsymbol(P)
    attrs["energy_unit"] = unitsymbol(E)

    attrs["start_timestamp"] = string(sys.timestamps.start);
    attrs["pras_dataversion"] = PRAS_VERSION

    return

end

function process_regions!(
    f::File, sys::SystemModel, strlen::Int, compression::Int)
   
    n_regions = length(sys.regions.names)

    regions = create_group(f, "regions")
    regions_core = reshape(sys.regions.names, :, 1)
    regions_core_colnames = ["name"]

    string_table!(regions, "_core", regions_core_colnames, regions_core, strlen)

    regions["load", compress = compression] = sys.regions.load

    return

end

function process_generators!(
    f::File, sys::SystemModel, strlen::Int, compression::Int)
   
    generators = create_group(f, "generators")

    gens_core = Matrix{String}(undef, length(sys.generators), 3)
    gens_core_colnames = ["name", "category", "region"]

    gens_core[:, 1] = sys.generators.names
    gens_core[:, 2] = sys.generators.categories
    gens_core[:, 3] = regionnames(
        length(sys.generators), sys.regions.names, sys.region_gen_idxs)

    string_table!(generators, "_core", gens_core_colnames, gens_core, strlen)

    generators["capacity", compress = compression] = sys.generators.capacity

    generators["failureprobability", compress = compression] = sys.generators.λ

    generators["repairprobability", compress = compression] = sys.generators.μ

    return

end

function process_storages!(
    f::File, sys::SystemModel, strlen::Int, compression::Int)
    
    storages = create_group(f, "storages")

    stors_core = Matrix{String}(undef, length(sys.storages), 3)
    stors_core_colnames = ["name", "category", "region"]

    stors_core[:, 1] = sys.storages.names
    stors_core[:, 2] = sys.storages.categories
    stors_core[:, 3] = regionnames(
        length(sys.storages), sys.regions.names, sys.region_stor_idxs)

    string_table!(storages, "_core", stors_core_colnames, stors_core, strlen)

    storages["chargecapacity", compress = compression] =
        sys.storages.charge_capacity

    storages["dischargecapacity", compress = compression] =
        sys.storages.discharge_capacity

    storages["energycapacity", compress = compression] =
        sys.storages.energy_capacity

    storages["chargeefficiency", compress = compression] =
        sys.storages.charge_efficiency

    storages["dischargeefficiency", compress = compression] =
        sys.storages.discharge_efficiency

    storages["carryoverefficiency", compress = compression] =
         sys.storages.carryover_efficiency

    storages["failureprobability", compress = compression] = sys.storages.λ

    storages["repairprobability", compress = compression] = sys.storages.μ

    return

end

function process_generatorstorages!(
    f::File, sys::SystemModel, strlen::Int, compression::Int)
   
    generatorstorages = create_group(f, "generatorstorages")

    genstors_core = Matrix{String}(undef, length(sys.generatorstorages), 3)
    genstors_core_colnames = ["name", "category", "region"]

    genstors_core[:, 1] = sys.generatorstorages.names
    genstors_core[:, 2] = sys.generatorstorages.categories
    genstors_core[:, 3] = regionnames(
        length(sys.generatorstorages), sys.regions.names, sys.region_genstor_idxs)

    string_table!(generatorstorages, "_core",
                  genstors_core_colnames, genstors_core, strlen)

    generatorstorages["inflow", compress = compression] =
        sys.generatorstorages.inflow

    generatorstorages["gridwithdrawalcapacity", compress = compression] =
        sys.generatorstorages.gridwithdrawal_capacity

    generatorstorages["gridinjectioncapacity", compress = compression] =
        sys.generatorstorages.gridinjection_capacity

    generatorstorages["chargecapacity", compress = compression] =
        sys.generatorstorages.charge_capacity

    generatorstorages["dischargecapacity", compress = compression] =
        sys.generatorstorages.discharge_capacity

    generatorstorages["energycapacity", compress = compression] =
        sys.generatorstorages.energy_capacity

    generatorstorages["chargeefficiency", compress = compression] =
        sys.generatorstorages.charge_efficiency

    generatorstorages["dischargeefficiency", compress = compression] =
        sys.generatorstorages.discharge_efficiency

    generatorstorages["carryoverefficiency", compress = compression] =
        sys.generatorstorages.carryover_efficiency

    generatorstorages["failureprobability", compress = compression] =
        sys.generatorstorages.λ

    generatorstorages["repairprobability", compress = compression] =
        sys.generatorstorages.μ

    return

end

function process_lines_interfaces!(
    f::File, sys::SystemModel, strlen::Int, compression::Int)
   
    lines = create_group(f, "lines")

    lines_core = Matrix{String}(undef, length(sys.lines), 4)
    lines_core_colnames = ["name", "category", "region_from", "region_to"]

    lines_core[:, 1] = sys.lines.names
    lines_core[:, 2] = sys.lines.categories
    for (lines, r_from, r_to) in zip(sys.interface_line_idxs,
                                     sys.interfaces.regions_from,
                                     sys.interfaces.regions_to)
        lines_core[lines, 3] .= sys.regions.names[r_from]
        lines_core[lines, 4] .= sys.regions.names[r_to]
    end

    string_table!(lines, "_core", lines_core_colnames, lines_core, strlen)

    lines["forwardcapacity", compress = compression] =
        sys.lines.forward_capacity

    lines["backwardcapacity", compress = compression] =
        sys.lines.backward_capacity

    lines["failureprobability", compress = compression] = sys.lines.λ

    lines["repairprobability", compress = compression] = sys.lines.μ


    interfaces = create_group(f, "interfaces")

    ints_core = Matrix{String}(undef, length(sys.interfaces), 2)
    ints_core_colnames = ["region_from", "region_to"]

    ints_core[:, 1] =
        getindex.(Ref(sys.regions.names), sys.interfaces.regions_from)
    ints_core[:, 2] =
        getindex.(Ref(sys.regions.names), sys.interfaces.regions_to)
    string_table!(interfaces, "_core", ints_core_colnames, ints_core, strlen)

    interfaces["forwardcapacity", compress = compression] =
        sys.interfaces.limit_forward

    interfaces["backwardcapacity", compress = compression] =
        sys.interfaces.limit_backward

    return

end

function regionnames(
    n_units::Int, regions::Vector{String}, unit_idxs::Vector{UnitRange{Int}})

    result = Vector{String}(undef, n_units)
    for (r, units) in enumerate(unit_idxs)
        result[units] .= regions[r]
    end

    return result

end

function string_table!(
    f::Group, tablename::String, colnames::Vector{String},
    data::Matrix{String}, strlen::Int
)

    nrows, ncols = size(data)

    length(colnames) == ncols ||
        error("Number of column names does not match provided data")

    allunique(colnames) ||
        error("All column names must be unique")

    all(x -> x <= strlen, length.(data)) ||
        error("Input data exceeds the specified HDF5 string length")

    stringtype_id = h5t_copy(hdf5_type_id(String))
    h5t_set_size(stringtype_id, strlen)
    stringtype = Datatype(stringtype_id)

    dt_id = h5t_create(H5T_COMPOUND, ncols * strlen)
    for (i, colname) in enumerate(colnames)
        h5t_insert(dt_id, colname, (i-1)*strlen, stringtype)
    end

    rawdata = UInt8.(vcat(vec(convertstring.(permutedims(data), strlen))...))

    dset = create_dataset(f, tablename, Datatype(dt_id),
                               dataspace((nrows,)))
    h5d_write(
        dset, dt_id, H5S_ALL, H5S_ALL, H5P_DEFAULT, rawdata)

end

function convertstring(s::AbstractString, strlen::Int)

    oldstring = ascii(s)
    newstring = fill('\0', strlen)

    for i in 1:min(strlen, length(s))
        newstring[i] = oldstring[i]
    end

    return newstring

end
