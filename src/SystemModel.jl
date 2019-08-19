struct SystemModel{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    regions::Regions{N,P}
    generators::Generators{N,L,T,P}
    storages::Storages{N,L,T,P,E}
    generatorstorages::GeneratorStorages{N,L,T,P,E}

    interfaces::Interfaces{N,P}
    lines::Lines{N,L,T,P}

    # starting index of each region in the generator vector
    # e.g. for region i, corresponding generators are stored in
    # generators[generators_regionstart[i]:generators_regionsstart[i+1]-1]
    # (in the last region i == length(regions), it would be
    # generators[generators_regionstart[i]:end])
    generators_regionstart::Vector{Int}
    storages_regionstart::Vector{Int}
    generatorstorages_regionstart::Vector{Int}
    lines_interfacestart::Vector{Int}

    timestamps::StepRange{DateTime,T}

    function SystemModel{N,L,T,P,E}(
        regions::Regions{N,P},
        generators::Generators{N,L,T,P},
        storages::Storages{N,L,T,P,E},
        generatorstorages::GeneratorStorages{N,L,T,P,E},
        interfaces::Interfaces{N,P},
        lines::Lines{N,L,T,P},
        generators_regionstart::Vector{Int},
        storages_regionstart::Vector{Int},
        generatorstorages_regionstart::Vector{Int},
        lines_interfacestart::Vector{Int},
        timestamps::StepRange{DateTime,T}
    ) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

        n_regions = length(regions)
        n_generators = length(generators)
        n_storages = length(storages)
        n_generatorstorages = length(generatorstorages)

        n_interfaces = length(interfaces)
        n_lines = length(lines)

        @assert length(generators_regionstart) == n_regions
        @assert issorted(generators_regionstart)
        @assert first(generators_regionstart) == 1
        @assert last(generators_regionstart) <= n_generators + 1

        @assert length(storages_regionstart) == n_regions
        @assert issorted(storages_regionstart)
        @assert first(storages_regionstart) == 1
        @assert last(storages_regionstart) <= n_storages + 1

        @assert length(generatorstorages_regionstart) == n_regions
        @assert issorted(generatorstorages_regionstart)
        @assert first(generatorstorages_regionstart) == 1
        @assert last(generatorstorages_regionstart) <= n_generatorstorages + 1

        @assert length(lines_interfacestart) == n_interfaces
        @assert issorted(lines_interfacestart)
        if n_lines > 0
            @assert first(lines_interfacestart) == 1
            @assert lines_interfacestart[end] <= n_lines + 1
        end

        @assert all(
            1 <= interfaces.regions_from[i] < interfaces.regions_to[i] <= n_regions
            for i in 1:n_interfaces)

        @assert step(timestamps) == T(L)
        @assert length(timestamps) == N

        new{N,L,T,P,E}(
            regions, generators, storages, generatorstorages,
            interfaces, lines,
            generators_regionstart, storages_regionstart,
            generatorstorages_regionstart, lines_interfacestart,
            timestamps)

    end

end

# Single-node constructor
function SystemModel{N,L,T,P,E}(
    generators::Generators{N,L,T,P},
    storages::Storages{N,L,T,P,E},
    generatorstorages::GeneratorStorages{N,L,T,P,E},
    timestamps::StepRange{DateTime,T},
    load::Vector{Int}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    return SystemModel{N,L,T,P,E}(
        Regions{N,P}(["Region"], reshape(load, 1, :)),
        generators, storages, generatorstorages,
        Interfaces{N,P}(
            Int[], Int[],
            Matrix{Int}(undef, 0, N), Matrix{Int}(undef, 0, N)),
        Lines{N,L,T,P}(
            String[], String[],
            Matrix{Int}(undef, 0, N), Matrix{Int}(undef, 0, N),
            Matrix{Float64}(undef, 0, N), Matrix{Float64}(undef, 0, N)),
        [1], [1], [1], Int[], timestamps)

end
