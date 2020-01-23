_Note: A useful reference for HDF5 file structure concepts is the
[HDF5 Glossary](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary).
This document contains links to glossary entries to explain HDF5 terms when used
for the first time._

# `SystemModel` HDF5 representation specification

This document specifies a representation of the PRAS `SystemModel` data
structure in terms of
[objects](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary#HDF5Glossary-Object)
in an HDF5 file. This specification is version-controlled in the same
repository as the `SystemModel` source code: any time the `SystemModel`
definition is changed, those updates are expected to be reconciled with this
document as appropriate. The version of this specification should therefore be
taken as the version of the package containing this file.

## Filename extension

By convention, HDF5 file representations of a PRAS `SystemModel` struct are
often given ".pras" filename extensions. This is merely a convenience to more
readily distinguish such files from other HDF5 files on the filesystem (which
will likely have ".h5" or ".hdf5" extensions), and is purely optional.

## PRAS terminology

In the following specification, generators, generator-storage units, storage
devices, and lines are sometimes refered to generically as "resources".
Similarly, regions (a grouping of generators, generator-storage units, and
storage devices) and interfaces (a grouping of lines) are sometimes referred
to generically as "resource collections".

## HDF5 File Structure

The HDF5 file must define five
[attributes](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary#HDF5Glossary-Attribute)
on the
[root group](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary#HDF5Glossary-Rootgroup).
These attributes are all mandatory:

 - `pras_dataversion`, signalling that this file is a representation of a PRAS
   `SystemModel` and providing the version of this specification used to
   create the file
 - `start_timestamp`, providing the timestamp of the first period of the
   simulation in ISO-8601 format
 - `timestep_count`, providing the number of timesteps in the simulation
 - `timestep_length`, providing the length (in `timestep_unit`s) of each
   timestep in the simulation
 - `timestep_unit`, providing the time units for `timestep_length`

The file may also define the following six
[groups](https://portal.hdfgroup.org/display/HDF5/HDF5+Glossary#HDF5Glossary-Group)
as children of the root group. At least two groups are mandatory.

The file must include:

 - `regions`, containing datasets describing regions in the system. This group
   is mandatory as any system must have at least one region

The file must include at least one of:

 - `generators`, containing datasets describing generators in the system
 - `generatorstorages`, containing datasets describing generator-storage units
   in the system

The file may include (optional):

 - `storages`, containing datasets describing storage devices in the system
 - `interfaces`, containing datasets describing collections of lines between
   regions in the system. This group **must** be included if `lines` is included
   and **must not** be included if `lines` is omitted.
 - `lines`, containing datasets describing transmission lines between regions
   in the system. This group **must** be included if `interfaces` is included
   and **must not** be included if `interfaces` is omitted.

Each of these attributes, groups and their required contents are explained in more detail
below.
      
### `pras_dataversion` root group attribute

The version of this HDF5 representation specification used to create the 
HDF5 file should be stored in an attribute of the file's root group
labelled `pras_dataversion`. The attribute should provide a single
nine-character string, taking the value of the abridged semantic versioning
representation of the specification version, `vXX.YY.ZZ`, where XX, YY, and ZZ
represent the major, minor, and patch version numbers of the specification,
respectively (when any of the version numbers require fewer than two digits to
represent, the end of the string can be padded with spaces).

As discussed above, the version of the specification is the same as the version
of the PRASBase.jl package providing the specification, and so should
match the version provided in the package's Project.toml file.

(A given version of PRASBase.jl will check this attribute to determine if it is
capable of reading the provided file, and if so, how to do so. While PRASBase
is usually capable of reading files associated with PRASBase versions older
than itself, it can only write files associated with its own version.)

### `start_timestamp` root group attribute

The starting timestamp for the system simulation should be stored in an attribute
of the file's root group labelled `start_timestamp`, as a single
25-character, ISO-8601-compliant string in a format matching
`2020-12-31T23:59:59-07:00`, providing year, month, day, hour, minute, second,
and timezone offset from UTC (in that order).

### `timestep_count` root group attribute

The total number of timesteps in the simulation should be stored in an
attribute of the file's root group labelled `timestep_count`, as a single
32-bit unsigned integer. The attribute value should match the number of rows
(in C/HDF5 row-major format) in each property dataset in the various resource and
resource collection groups.

### `timestep_length` root group attribute

The length of a single timestep (in terms of the units defined by
`timestep_unit`) should be stored in an attribute of the file's root group
labelled `timestep_length`, as a single 32-bit unsigned integer.

### `timestep_unit` root group attribute

The units for `timestep_length` should be stored in an attribute of the file's
root group labelled `timestep_unit`, as a single three-character string. The
following are recognized values for the string to take:

 - `sec` indicates the units are seconds
 - `min` indicates the units are minutes
 - `hr ` indicates the units are hours
 - `day` indicates the units are days

### `regions` group

### `generators` group

### `storages` group

### `generatorstorages` group

### `interfaces` group

### `lines` group
