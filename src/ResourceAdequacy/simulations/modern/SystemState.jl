struct SystemState

    gens_available::Vector{Bool}
    gens_nexttransition::Vector{Int}

    stors_available::Vector{Bool}
    stors_nexttransition::Vector{Int}
    stors_energy::Vector{Int}

    genstors_available::Vector{Bool}
    genstors_nexttransition::Vector{Int}
    genstors_energy::Vector{Int}

    lines_available::Vector{Bool}
    lines_nexttransition::Vector{Int}

    function SystemState(system::SystemModel)

        ngens = length(system.generators)
        gens_available = Vector{Bool}(undef, ngens)
        gens_nexttransition= Vector{Int}(undef, ngens)

        nstors = length(system.storages)
        stors_available = Vector{Bool}(undef, nstors)
        stors_nexttransition = Vector{Int}(undef, nstors)
        stors_energy = Vector{Int}(undef, nstors)

        ngenstors = length(system.generatorstorages)
        genstors_available = Vector{Bool}(undef, ngenstors)
        genstors_nexttransition = Vector{Int}(undef, ngenstors)
        genstors_energy = Vector{Int}(undef, ngenstors)

        nlines = length(system.lines)
        lines_available = Vector{Bool}(undef, nlines)
        lines_nexttransition = Vector{Int}(undef, nlines)

        return new(
            gens_available, gens_nexttransition,
            stors_available, stors_nexttransition, stors_energy,
            genstors_available, genstors_nexttransition, genstors_energy,
            lines_available, lines_nexttransition)

    end

end
