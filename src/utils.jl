normdist = Normal()
function pequal(x::T, y::T) where {T<:RA.ReliabilityMetric}
    z = abs((RA.val(x) - RA.val(y)) /
            sqrt(RA.stderr(x)^2 + RA.stderr(y)^2))
    return 2 * ccdf(normdist, z)
end

function addfirmcapacity(sys::RA.SystemModel{N1,T1,N2,T2,P,V},
                         nodes::Generic{Int,Float64,Vector{Int}},
                         capacity::Float64) where {N1,T1,N2,T2,P,V}

    gens_updated     = copy(sys.generators)
    gens_regionstart = copy(sys.generators_regionstart)
    n_gen_cols       = size(gens_updated, 2)

    for (node, weight) in zip(support(nodes), Distributions.probs(nodes))

        firm_gen = ResourceAdequacy.DispatchableGeneratorSpec(
                       weight*capacity, 0.0, 1.0)
        regionstart_idx = gens_regionstart[node]
        gens_updated = [gens_updated[1:(regionstart_idx-1), :];
                        fill(firm_gen, 1, n_gen_cols);
                        gens_updated[regionstart_idx:end, :]
                       ]
        gens_regionstart[(node+1):end] .+= 1

    end

    return RA.SystemModel{N1,T1,N2,T2,P,V}(
        sys.regions, gens_updated, gens_regionstart,
        sys.storages, sys.storages_regionstart,
        sys.interfaces, sys.lines, sys.lines_interfacestart,
        sys.timestamps, sys.timestamps_generatorset,
        sys.timestamps_storageset, sys.timestamps_lineset,
        sys.vg, sys.load)

end
