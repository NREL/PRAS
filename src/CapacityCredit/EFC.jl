struct EFC{M} <: CapacityValuationMethod{M}
    capacity_max::Int
    capacity_gap::Int
    p_value::Float64
    regions::Vector{Tuple{String, Float64}}
    verbose::Bool

    function EFC{M}(
        capacity_max::Int,
        regions::Vector{Pair{String, Float64}};
        capacity_gap::Int=1,
        p_value::Float64=0.05,
        verbose::Bool=false,
    ) where {M}
        @assert capacity_max > 0
        @assert capacity_gap > 0
        @assert 0 < p_value < 1
        @assert sum(x.second for x in regions) ≈ 1.0

        return new{M}(capacity_max, capacity_gap, p_value, Tuple.(regions), verbose)
    end
end

function EFC{M}(capacity_max::Int, region::String; kwargs...) where {M}
    return EFC{M}(capacity_max, [region => 1.0]; kwargs...)
end

function assess(
    sys_baseline::S,
    sys_augmented::S,
    params::EFC{M},
    simulationspec::SimulationSpec,
) where {N, L, T, P, S <: SystemModel{N, L, T, P}, M <: ReliabilityMetric}
    _, powerunit, _ = unitsymbol(sys_baseline)

    regionnames = sys_baseline.regions.names
    regionnames != sys_augmented.regions.names &&
        error("Systems provided do not have matching regions")

    # Add firm capacity generators to the relevant regions
    efc_gens, sys_variable, sys_target =
        add_firmcapacity(sys_baseline, sys_augmented, params.regions)

    target_metric = M(first(assess(sys_target, simulationspec, Shortfall())))

    capacities = Int[]
    metrics = typeof(target_metric)[]

    lower_bound = 0
    lower_bound_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(capacities, lower_bound)
    push!(metrics, lower_bound_metric)

    upper_bound = params.capacity_max
    update_firmcapacity!(sys_variable, efc_gens, upper_bound)
    upper_bound_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(capacities, upper_bound)
    push!(metrics, upper_bound_metric)

    while true
        params.verbose && println(
            "\n$(lower_bound) $powerunit\t< EFC <\t$(upper_bound) $powerunit\n",
            "$(lower_bound_metric)\t> $(target_metric) >\t$(upper_bound_metric)",
        )

        midpoint = div(lower_bound + upper_bound, 2)
        capacity_gap = upper_bound - lower_bound

        # Stopping conditions

        ## Return the bounds if they are within solution tolerance of each other
        if capacity_gap <= params.capacity_gap
            params.verbose &&
                @info "Capacity bound gap within tolerance, stopping bisection."
            break
        end

        # If the null hypothesis lower_bound_metric !>= upper_bound_metric
        # cannot be rejected, terminate and return the loose bounds
        pval = pvalue(upper_bound_metric, lower_bound_metric)
        if pval >= params.p_value
            @warn "Gap between upper and lower bound risk metrics is not " *
                  "statistically significant (p_value=$pval), stopping bisection. " *
                  "The gap between capacity bounds is $(capacity_gap) $powerunit, " *
                  "while the target stopping gap was $(params.capacity_gap) $powerunit."
            break
        end

        # Evaluate metric at midpoint
        update_firmcapacity!(sys_variable, efc_gens, midpoint)
        midpoint_metric = M(first(assess(sys_variable, simulationspec, Shortfall())))
        push!(capacities, midpoint)
        push!(metrics, midpoint_metric)

        # Tighten capacity bounds
        if val(midpoint_metric) > val(target_metric)
            lower_bound = midpoint
            lower_bound_metric = midpoint_metric
        else # midpoint_metric <= target_metric
            upper_bound = midpoint
            upper_bound_metric = midpoint_metric
        end
    end

    return CapacityCreditResult{typeof(params), typeof(target_metric), P}(
        target_metric,
        lower_bound,
        upper_bound,
        capacities,
        metrics,
    )
end

function add_firmcapacity(
    s1::SystemModel{N, L, T, P, E},
    s2::SystemModel{N, L, T, P, E},
    region_shares::Vector{Tuple{String, Float64}},
) where {N, L, T, P, E}
    n_regions = length(s1.regions.names)
    n_region_allocs = length(region_shares)

    region_allocations = allocate_regions(s1.regions.names, region_shares)
    efc_gens = similar(region_allocations)

    new_gen(i::Int) = Generators{N, L, T, P}(
        ["_EFC_$i"],
        ["_EFC Calculation Dummy Generator"],
        zeros(Int, 1, N),
        zeros(1, N),
        ones(1, N),
    )

    variable_gens = Generators{N, L, T, P}[]
    variable_region_gen_idxs = similar(s1.region_gen_idxs)

    target_gens = similar(variable_gens)
    target_region_gen_idxs = similar(s2.region_gen_idxs)

    ra_idx = 0

    for r in 1:n_regions
        s1_range = s1.region_gen_idxs[r]
        s2_range = s2.region_gen_idxs[r]

        if (ra_idx < n_region_allocs) && (r == first(region_allocations[ra_idx + 1]))
            ra_idx += 1

            variable_region_gen_idxs[r] = incr_range(s1_range, ra_idx - 1, ra_idx)
            target_region_gen_idxs[r] = incr_range(s2_range, ra_idx - 1, ra_idx)

            gen = new_gen(ra_idx)
            push!(variable_gens, gen)
            push!(target_gens, gen)
            efc_gens[ra_idx] =
                (first(s1_range) + ra_idx - 1, last(region_allocations[ra_idx]))

        else
            variable_region_gen_idxs[r] = incr_range(s1_range, ra_idx)
            target_region_gen_idxs[r] = incr_range(s2_range, ra_idx)
        end

        push!(variable_gens, s1.generators[s1_range])
        push!(target_gens, s2.generators[s2_range])
    end

    sys_variable = SystemModel(
        s1.regions,
        s1.interfaces,
        vcat(variable_gens...),
        variable_region_gen_idxs,
        s1.storages,
        s1.region_stor_idxs,
        s1.generatorstorages,
        s1.region_genstor_idxs,
        s1.lines,
        s1.interface_line_idxs,
        s1.timestamps,
    )

    sys_target = SystemModel(
        s2.regions,
        s2.interfaces,
        vcat(target_gens...),
        target_region_gen_idxs,
        s2.storages,
        s2.region_stor_idxs,
        s2.generatorstorages,
        s2.region_genstor_idxs,
        s2.lines,
        s2.interface_line_idxs,
        s2.timestamps,
    )

    return efc_gens, sys_variable, sys_target
end

function update_firmcapacity!(
    sys::SystemModel,
    gens::Vector{Tuple{Int, Float64}},
    capacity::Int,
)
    for (g, share) in gens
        sys.generators.capacity[g, :] .= round(Int, share * capacity)
    end
end
