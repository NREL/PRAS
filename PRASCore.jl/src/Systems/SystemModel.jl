"""
    SystemModel

A `SystemModel` contains a representation of a power system to be studied
with PRAS.
"""
struct SystemModel{N, L, T <: Period, P <: PowerUnit, E <: EnergyUnit}
    regions::Regions{N, P}
    interfaces::Interfaces{N, P}

    generators::Generators{N,L,T,P}
    region_gen_idxs::Vector{UnitRange{Int}}

    storages::Storages{N,L,T,P,E}
    region_stor_idxs::Vector{UnitRange{Int}}

    generatorstorages::GeneratorStorages{N,L,T,P,E}
    region_genstor_idxs::Vector{UnitRange{Int}}

    lines::Lines{N,L,T,P}
    interface_line_idxs::Vector{UnitRange{Int}}

    timestamps::StepRange{ZonedDateTime,T}

    attrs::Union{Dict{String, String},Nothing}

    function SystemModel{}(
        regions::Regions{N,P}, interfaces::Interfaces{N,P},
        generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
        storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
        generatorstorages::GeneratorStorages{N,L,T,P,E},
        region_genstor_idxs::Vector{UnitRange{Int}},
        lines::Lines{N,L,T,P}, interface_line_idxs::Vector{UnitRange{Int}},
        timestamps::StepRange{ZonedDateTime,T};
        attrs::Union{Dict{String, String},Nothing}=nothing
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
            timestamps,attrs)

    end

end

# No time zone constructor
function SystemModel(
    regions::Regions{N,P}, interfaces::Interfaces{N,P},
    generators::Generators{N,L,T,P}, region_gen_idxs::Vector{UnitRange{Int}},
    storages::Storages{N,L,T,P,E}, region_stor_idxs::Vector{UnitRange{Int}},
    generatorstorages::GeneratorStorages{N,L,T,P,E}, region_genstor_idxs::Vector{UnitRange{Int}},
    lines, interface_line_idxs::Vector{UnitRange{Int}},
    timestamps::StepRange{DateTime,T}
) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}

    @warn "No time zone data provided - defaulting to UTC. To specify a " *
          "time zone for the system timestamps, provide a range of " *
          "`ZonedDateTime` instead of `DateTime`."

    utc = tz"UTC"
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

isnonnegative(x::Real) = x >= 0
isfractional(x::Real) = 0 <= x <= 1

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

function get_sys_attrs(sys::SystemModel{N,L,T,P,E}) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}
    if sys.attrs === nothing
        return Dict{String, String}()
    else
        return sys.attrs
    end
end

function Base.show(io::IO, sys::SystemModel{N,L,T,P,E}) where {N,L,T<:Period,P<:PowerUnit,E<:EnergyUnit}
    _, power_unit, energy_unit = unitsymbol(sys)
    time_unit = unitsymbol_long(T)
    print(io, "SystemModel($(length(sys.regions)) regions, $(length(sys.interfaces)) interfaces, ",
          "$(length(sys.generators)) generators, $(length(sys.storages)) storages, ",
          "$(length(sys.generatorstorages)) generator-storages, $(length(sys.interfaces)) interfaces, ",
          "$(N) $(time_unit)s)")
end

function Base.show(io::IO, ::MIME"text/plain", sys::SystemModel{N,L,T,P,E}) where {N,L,T,P,E}
    _, power_unit, energy_unit = unitsymbol(sys)
    time_unit = unitsymbol_long(T)
    println(io, "\nPRAS system with $(length(sys.regions)) regions, and $(length(sys.interfaces)) interfaces between these regions.")
    println(io, "Region names: $(join(sys.regions.names, ", "))")
    println(io, "Assets: ")
    println(io, "  Generators: $(length(sys.generators)) ")
    println(io, "  Storage devices: $(length(sys.storages))")
    println(io, "  Generator-storage hybrids: $(length(sys.generatorstorages))")
    println(io, "  Lines: $(length(sys.lines))")
    println(io, "\nNumber of time periods in system timeseries data: $(N) $(time_unit)s")
    
    # Format attributes as key-value pairs
    sys_attributes = get_sys_attrs(sys)
    if !isempty(sys_attributes)
        println(io, "\nAttributes:")
        for (key, value) in sys_attributes
            println(io, "  $key: $value")
        end
    else
        println(io, "\nAttributes: None")
    end
end

struct RegionInfo
    name::String
    index::Int
    generators::NamedTuple
    storages::NamedTuple
    generatorstorages::NamedTuple
    peak_load::Int
    power_unit::String
end

"""
Access region information from a SystemModel by region name (String) or region index (Int)
"""
function Base.getindex(sys::SystemModel, region::Union{String,Int})
    region_idx = if isa(region, String)
        findfirst(==(region), sys.regions.names)
    else
        region
    end
    
    if region_idx === nothing || region_idx < 1 || region_idx > length(sys.regions)
        if isa(region, String)
            throw(KeyError("Region '$(region)' not found in system model"))
        else
            throw(BoundsError(sys.regions, region))
        end
    end
    
    region_name = sys.regions.names[region_idx]
    time_unit, power_unit, energy_unit = unitsymbol(sys)
    
    # Get generators in this region
    gen_range = sys.region_gen_idxs[region_idx]
    region_gens = sys.generators.names[gen_range]
    
    # Get storage devices in this region
    stor_range = sys.region_stor_idxs[region_idx]
    region_stors = sys.storages.names[stor_range]
    
    # Get generator-storage hybrids in this region
    genstor_range = sys.region_genstor_idxs[region_idx]
    region_genstors = sys.generatorstorages.names[genstor_range]
    
    # Get peak load for this region
    peak_load = maximum(sys.regions.load[region_idx, :])
    
    # Return a RegionInfo object with all the information
    return RegionInfo(
        region_name,
        region_idx,
        (
            names = region_gens,
            count = length(region_gens),
        ),
        (
            names = region_stors,
            count = length(region_stors),
        ),
        (
            names = region_genstors,
            count = length(region_genstors),
        ),
        peak_load,
        power_unit,
    )
end

function Base.show(io::IO, info::RegionInfo)
    println(io, "Region: $(info.name) (index - $(info.index))")
    println(io, "  Peak load: $(info.peak_load) $(info.power_unit)")
    println(io, "  Generators: $(info.generators.count) units")
    println(io, "  Storages: $(info.storages.count) units")
    print(io, "  Generator-storage hybrids: $(info.generatorstorages.count) units")
end
