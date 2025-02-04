module PRASFiles

const PRASFILE_VERSION = "v0.7.0"

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                         Generators, Storages, GeneratorStorages, Lines,
                         timeunits, powerunits, energyunits, unitsymbol

import PRASCore.Results: EUE, LOLE, ShortfallResult, SurplusResult, StorageEnergyResult, Result

import Dates: @dateformat_str
import TimeZones: ZonedDateTime
import HDF5: HDF5, attributes, File, Group, Dataset, Datatype, dataspace,
             h5open, create_group, create_dataset, hdf5_type_id
import HDF5.API: h5t_create, h5t_copy, h5t_insert, h5t_set_size,
                 H5T_COMPOUND, h5d_write, H5S_ALL, H5P_DEFAULT

export savemodel

include("Systems/read.jl")
include("Systems/write.jl")
include("Systems/utils.jl")

function toymodel()
    path = dirname(@__FILE__)
    return SystemModel(joinpath(path, "Systems","toymodel.pras")) 
end

function rts_gmlc()
    path = dirname(@__FILE__)
    return SystemModel(joinpath(path, "Systems","rts.pras")) 
end

end
