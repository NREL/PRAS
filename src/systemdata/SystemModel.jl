struct SystemModel{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    regions::Vector{String} # region names

    generators::Matrix{DispatchableGeneratorSpec{V}} # generators x unique sets
    generators_regionstart::Vector{Int} # starting index of each region
                                        # in the generator vector
    # e.g. for region i, corresponding units are stored in
    # generators[generators_regionstart[i]:generators_regionsstart[i+1]-1]
    # (in the last region i == length(regions), it would be
    # generators[generators_regionstart[i]:end])

    storages::Matrix{StorageDeviceSpec{V}} # devices x unique sets
    storages_regionstart::Vector{Int} # starting index of each region
                                      # in the storage device vector

    interfaces::Vector{Tuple{Int,Int}}

    lines::Matrix{LineSpec{V}} # lines x unique sets
    lines_interfacestart::Vector{Int} # starting index of each line
                                      # in the line vector

    timestamps::StepRange{DateTime,T}
    timestamps_generatorset::Vector{Int} # generator property set for each timestamp
    timestamps_storageset::Vector{Int} # storage device property set for each timestamp
    timestamps_lineset::Vector{Int} # line property set for each timestamp

    vg::Matrix{V} # regions x timestamps
    load::Matrix{V} # regions x timestamps

    function SystemModel{N,L,T,P,E}(
        regions::Vector{String},
        generators::Matrix{DispatchableGeneratorSpec{V}},
        generators_regionstart::Vector{Int},
        storages::Matrix{StorageDeviceSpec{V}},
        storages_regionstart::Vector{Int},
        interfaces::Vector{Tuple{Int,Int}},
        lines::Matrix{LineSpec{V}},
        lines_interfacestart::Vector{Int},
        timestamps::StepRange{DateTime,T},
        timestamps_generatorset::Vector{Int},
        timestamps_storageset::Vector{Int},
        timestamps_lineset::Vector{Int},
        vg::Matrix{V},
        load::Matrix{V}
    ) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

        n_regions = length(regions)
        n_interfaces = length(interfaces)

        @assert length(generators_regionstart) == n_regions
        @assert issorted(generators_regionstart)
        @assert first(generators_regionstart) == 1
        @assert last(generators_regionstart) <= size(generators, 1) + 1

        @assert length(storages_regionstart) == n_regions
        @assert issorted(storages_regionstart)
        @assert first(storages_regionstart) == 1
        @assert last(storages_regionstart) <= size(storages, 1) + 1

        @assert length(lines_interfacestart) == n_interfaces
        @assert issorted(lines_interfacestart)
        size(lines, 1) > 0 &&
            @assert lines_interfacestart[end] <= size(lines, 1)

        @assert step(timestamps) == T(L)
        @assert length(timestamps) == N
        @assert N == length(timestamps_generatorset)
        @assert N == length(timestamps_storageset)
        @assert N == length(timestamps_lineset)

        @assert size(vg) == (n_regions, N)
        @assert size(load) == (n_regions, N)

        new{N,L,T,P,E,V}(
            regions,
            generators, generators_regionstart,
            storages, storages_regionstart,
            interfaces,
            lines, lines_interfacestart,
            timestamps, timestamps_generatorset,
            timestamps_storageset, timestamps_lineset,
            vg, load)

    end

end

# Single-node constructor
function SystemModel{N,L,T,P,E}(
    generators::Matrix{DispatchableGeneratorSpec{V}},
    storages::Matrix{StorageDeviceSpec{V}},
    timestamps::StepRange{DateTime,T},
    timestamps_generatorset::Vector{Int},
    timestamps_storageset::Vector{Int},
    vg::Vector{V},
    load::Vector{V}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit,V<:Real}

    return SystemModel{N,L,T,P,E}(
        ["Region"], generators, [1], storages, [1],
        Tuple{Int,Int}[], Matrix{LineSpec{V}}(0,1), Int[],
        timestamps, timestamps_generatorset,
        timestamps_storageset, ones(Int, length(timestamps)),
        reshape(vg, 1, :), reshape(load, 1, :))

end
