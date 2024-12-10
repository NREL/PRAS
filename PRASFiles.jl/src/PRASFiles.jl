module PRASFiles

const PRASFILE_VERSION = "v0.7.0"

import PRASCore.Systems: SystemModel, Regions, Interfaces,
                         Generators, Storages, GeneratorStorages, Lines,
                         timeunits, powerunits, energyunits, unitsymbol

import Dates: @dateformat_str
import TimeZones: ZonedDateTime
import HDF5: HDF5, attributes, File, Group, Dataset, Datatype, dataspace,
             h5open, create_group, create_dataset, hdf5_type_id
import HDF5.API: h5t_create, h5t_copy, h5t_insert, h5t_set_size,
                 H5T_COMPOUND, h5d_write, H5S_ALL, H5P_DEFAULT

export savemodel

include("read.jl")
include("write.jl")
include("utils.jl")

function toymodel()
    path = dirname(@__FILE__)
    return SystemModel(path * "/toymodel.pras")
end

function rts_gmlc()
    path = dirname(@__FILE__)
    return SystemModel(path * "/rts.pras")
end

end