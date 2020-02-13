struct SystemModel{N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    regions::Regions{N,P}
    interfaces::Interfaces{N,P}

    generators::Generators{N,L,T,P}
    region_gen_idxs::Vector{UnitRange{Int}}

    storages::Storages{N,L,T,P,E}
    region_stor_idxs::Vector{UnitRange{Int}}

    generatorstorages::GeneratorStorages{N,L,T,P,E}
    region_genstor_idxs::Vector{UnitRange{Int}}

    lines::Lines{N,L,T,P}
    interface_line_idxs::Vector{UnitRange{Int}}

    timestamps::StepRange{ZonedDateTime,T}

    function SystemModel{N,L,T,P,E}(
        regions::Regions{N,P}, interfaces::Interfaces{N,P},
        generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
        storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
        generatorstorages::GeneratorStorages{N,L,T,P,E}, region_genstor_idxs::Vector{UnitRange{Int}},
        lines::Lines{N,L,T,P}, interface_line_idxs::Vector{UnitRange{Int}},
        timestamps::StepRange{DateTime,T}
    ) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

        n_regions = length(regions)
        n_gens = length(generators)
        n_stors = length(storages)
        n_genstors = length(generatorstorages)

        n_interfaces = length(interfaces)
        n_lines = length(lines)

        @assert consistent_idxs(region_gen_idxs, n_gens, n_regions)
        @assert consistent_idxs(region_stor_idxs, n_stors, n_regions)
        @assert consistent_idxs(region_genstor_idxs, n_genstors, n_regions)
        @assert consistent_idxs(interface_line_idxs, n_lines, n_interfaces)

        @assert all(
            1 <= interfaces.regions_from[i] < interfaces.regions_to[i] <= n_regions
            for i in 1:n_interfaces)

        @assert step(timestamps) == T(L)
        @assert length(timestamps) == N

        new{N,L,T,P,E}(
            regions, interfaces,
            generators, region_gen_idxs, storages, region_stor_idxs,
            generatorstorages, region_genstor_idxs, lines, interface_line_idxs,
            timestamps)

    end

end

function consistent_idxs(idxss::Vector{UnitRange{Int}}, nitems::Int, ngroups::Int)

    length(idxss) == ngroups || return false

    expected_next = 1
    for idxs in idxss
        first(idxs) == expected_next || return false
        expected_next = last(idxs) + 1
    end

    expected_next == nitems + 1 || return false
    return true

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
        Interfaces{N,P}(
            Int[], Int[],
            Matrix{Int}(undef, 0, N), Matrix{Int}(undef, 0, N)),
        generators, [1:length(generators)],
        storages, [1:length(storages)],
        generatorstorages, [1:length(generatorstorages)],
        Lines{N,L,T,P}(
            String[], String[],
            Matrix{Int}(undef, 0, N), Matrix{Int}(undef, 0, N),
            Matrix{Float64}(undef, 0, N), Matrix{Float64}(undef, 0, N)),
        UnitRange{Int}[], timestamps)

end
