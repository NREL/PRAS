normdist = Normal()
function pequal(x::T, y::T) where {T<:RA.ReliabilityMetric}
    z = abs((RA.val(x) - RA.val(y)) /
            sqrt(RA.stderr(x)^2 + RA.stderr(y)^2))
    return 2 * ccdf(normdist, z)
end

function addfirmcapacity(
    system::RA.SystemModel{N,L,T,P,E,V},
    regions::DiscreteNonParametric{Int,V,Vector{Int}},
    totalcapacity::V) where {N,L,T,P,E,V}

    regions_idxs = support(regions)
    region_shares = Distributions.probs(regions)

    n_gensets = size(system.generators, 2)
    newgenerators = system.generators
    newgenerators_regionstart = copy(system.generators_regionstart)

    for (r, share) in zip(region_idxs, region_shares)

        firmgen = RA.DispatchableGeneratorSpec(
            totalcapacity * share, 0., 1.)

        g = system.generators_regionstart[r]
        newgenerators = vcat(
            newgenerators[1:(g-1), :],
            fill(firmgen, 1, n_gensets),
            newgenerators[g:end, :]
        )
        newgenerators_regionstart[(r+1):end] .+= 1

    end

    return RA.SystemModel{N,L,T,P,E}(
        system.regions, newgenerators, newgenerators_regionstart,
        system.storages, system.storages_regionstart,
        system.interfaces, system.lines, system.lines_interfacestart,
        system.timestamps, system.timestamps_generatorset,
        system.timestamps_storageset, system.timestamps_lineset,
        system.vg, system.load)

end
