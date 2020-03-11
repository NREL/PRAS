function write(filename::String, system::SystemModel)

    h5open(filename, "w") do f::HDF5File
        # Save out regions
        # Save out generators
        # Save out storages
        # Save out generatorstorages
        # Save out interfaces
        # Save out lines
    end

end
