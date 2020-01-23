"""

    SystemModel(filename::String)

Load a `SystemModel` from an appropriately-formatted HDF5 file on disk.
"""
function SystemModel(inputfile::String)

    system = read(inputfile) do f::HDF5File

        version, versionstring = getversion(f)

        # Determine the appropriate version of the constructor to use 
        return if (0,2,2) <= version < (0,3,0)
            SystemModel(f, Val((0,2,2))
        else
            error("File format $versionstring not supported by this version of PRASBase.")
        end

    end

    return system

end


function SystemModel(f::HDF5File, ::Val{(0,2,2)})
    # create SystemModel
    # return SystemModel
end

"""
Attempts to parse the file's "vX.Y.Z" version label into (x::Int, y::Int, z::Int).
Errors if the label cannot be found or parsed as expected.
"""
function getversion(f::HDF5File)

    # TODO

    error("File format version indicator could not be found - the file may "
          "not be a PRAS SystemModel representation."

    error("File format version $versionstring not recognized")

    return versionstring, (major, minor, patch)

end
