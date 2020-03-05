"""

    SystemModel(filename::String)

Load a `SystemModel` from an appropriately-formatted HDF5 file on disk.
"""
function SystemModel(inputfile::String)

    system = h5open(inputfile, "r") do f::HDF5File

        version, versionstring = getversion(f)
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
                                     dateformat"yyyy-mm-ddTHH:MM:SSZ")

     N = read(metadata["timestep_count"])
     L = read(metadata["timestep_length"])
     T = timeunits[read(metadata["timestep_unit"])]
     P = powerunits[read(metadata["power_unit"])]
     E = energyunits[read(metadata["energy_unit"])]

    # Load all data

    regions = Regions{N,P}()
    generators = Generators{N,L,T,P}()
    storages = Storages{N,L,T,P,E}()
    generatorstorages = GeneratorStorages{N,L,T,P,E}()

    interfaces = Interfaces{N,P}()
    lines = Lines{N,L,T,P}()

    return SystemModel{N,L,T,P,E}(
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
function getversion(f::HDF5File)

    exists(attrs(f), "pras_dataversion") || error(
          "File format version indicator could not be found - the file may " *
          "not be a PRAS SystemModel representation.")

    versionstring = read(attrs(f)["pras_dataversion"])

    version = match(r"^v(\d+)\.(\d+)\.(\d+)$", versionstring)
    isnothing(version) && error("File format version $versionstring not recognized")

    major, minor, patch = parse.(Int, version.captures)

    return (major, minor, patch), versionstring

end
