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

    function SystemModel{}(
        regions::Regions{N,P}, interfaces::Interfaces{N,P},
        generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
        storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
        generatorstorages::GeneratorStorages{N,L,T,P,E},
        region_genstor_idxs::Vector{UnitRange{Int}},
        lines::Lines{N,L,T,P}, interface_line_idxs::Vector{UnitRange{Int}},
        timestamps::StepRange{ZonedDateTime,T}
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

# No time zone constructor
function SystemModel(
    regions, interfaces,
    generators, region_gen_idxs,
    storages, region_stor_idxs,
    generatorstorages, region_genstor_idxs,
    lines, interface_line_idxs,
    timestamps::StepRange{DateTime,T}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    @warn "No time zone data provided - defaulting to UTC. To specify a " *
          "time zone for the system timestamps, provide a range of " *
          "`ZonedDateTime` instead of `DateTime`."

    utc = TimeZone("UTC")
    time_start = ZonedDateTime(first(timestamps), utc)
    time_end = ZonedDateTime(last(timestamps), utc)
    timestamps_tz = time_start:step(timestamps):time_end

    return SystemModel(
        regions, interfaces,
        generators, region_gen_idxs,
        storages, region_stor_idxs,
        generatorstorages, region_genstor_idxs,
        lines, interface_line_idxs,
        timestamps_tz)

end

# Single-node constructor
function SystemModel(
    generators::Generators{N,L,T,P},
    storages::Storages{N,L,T,P,E},
    generatorstorages::GeneratorStorages{N,L,T,P,E},
    timestamps::StepRange{<:AbstractDateTime,T},
    load::Vector{Int}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    return SystemModel(
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

Base.:(==)(x::T, y::T) where {T <: SystemModel} =
    x.regions == y.regions &&
    x.interfaces == y.interfaces &&
    x.generators == y.generators &&
    x.region_gen_idxs == y.region_gen_idxs &&
    x.storages == y.storages &&
    x.region_stor_idxs == y.region_stor_idxs &&
    x.generatorstorages == y.generatorstorages &&
    x.region_genstor_idxs == y.region_genstor_idxs &&
    x.lines == y.lines &&
    x.interface_line_idxs == y.interface_line_idxs &&
    x.timestamps == y.timestamps

broadcastable(x::SystemModel) = Ref(x)

unitsymbol(::SystemModel{N,L,T,P,E}) where {
    N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit} =
    unitsymbol(T), unitsymbol(P), unitsymbol(E)

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
