struct EFC{M} <: CapacityValuationMethod{M}

    capacity_max::Int
    capacity_gap::Int
    p_value::Float64
    regions::Vector{Tuple{String,Float64}}
    verbose::Bool

    function EFC{M}(
        capacity_max::Int, regions::Vector{Pair{String,Float64}};
        capacity_gap::Int=1, p_value::Float64=0.05, verbose::Bool=false) where M

        @assert capacity_max > 0
        @assert capacity_gap > 0
        @assert 0 < p_value < 1
        @assert sum(x.second for x in regions) ≈ 1.0

        return new{M}(capacity_max, capacity_gap, p_value, Tuple.(regions), verbose)

    end

end

function EFC{M}(
    capacity_max::Int, region::String; kwargs...
) where M
    return EFC{M}(capacity_max, [region=>1.0]; kwargs...)
end

function assess(sys_baseline::S, sys_augmented::S,
                params::EFC{M}, simulationspec::SequentialMonteCarlo
) where {N, L, T, P, S <: SystemModel{N,L,T,P}, M <: ReliabilityMetric}

    _, powerunit, _ = unitsymbol(sys_baseline)

    regionnames = sys_baseline.regions.names
    regionnames != sys_augmented.regions.names &&
        error("Systems provided do not have matching regions")

    params.capacity_max > params.capacity_gap ||
        error("The max capacity addition ($(params.capacity_max)) must be " *
              "larger than the desired capacity gap ($(params.capacity_gap))")

    sys_variable, efc_gens = add_firmcapacity(sys_baseline, params.regions)

    target_risk = M(first(assess(sys_augmented, simulationspec, Shortfall())))

    efcs = Int[]
    risks = typeof(target_risk)[]

    min_efc = 0
    upper_risk = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(efcs, min_efc)
    push!(risks, upper_risk)

    prob_greater(target_risk, upper_risk) < params.p_value ||
        error("The baseline system risk ($(upper_risk)) is not statistically " *
              "distinguishable from the augmented system risk ($(target_risk))")

    max_efc = params.capacity_max
    update_firmcapacity!(sys_variable, efc_gens, max_efc)
    lower_risk = M(first(assess(sys_variable, simulationspec, Shortfall())))
    push!(efcs, max_efc)
    push!(risks, lower_risk)

    prob_greater(lower_risk, target_risk) < params.p_value ||
        error("The baseline system risk with the max capacity addition applied " *
              "($(lower_risk)) is not statistically distinguishable from the " *
              "augmented system risk ($(target_risk))")

    params.verbose && println(
        "\n$(min_efc) $powerunit\t< EFC <\t$(max_efc) $powerunit\n",
        "$(upper_risk)\t> $(target_risk) >\t$(lower_risk)")

    capacity_gap = max_efc - min_efc

    while true

        # Evaluate metric at midpoint

        mid_efc = div(min_efc + max_efc, 2)
        update_firmcapacity!(sys_variable, efc_gens, mid_efc)
        mid_risk = M(first(assess(sys_variable, simulationspec, Shortfall())))
        push!(efcs, mid_efc)
        push!(risks, mid_risk)

        # If the null hypothesis mid_risk == target_risk
        # cannot be rejected, terminate and return the loose bounds

        if prob_same(mid_risk, target_risk) >= params.p_value
            @warn "Risk at the midpoint between upper and lower EFC bounds is not " *
                  "statistically distinguishable from the augmented system risk, " *
                  "stopping bisection. " *
                  "The gap between capacity bounds is $(capacity_gap) $powerunit, " *
                  "while the target stopping gap was $(params.capacity_gap) $powerunit."
            break
        end

        # Tighten capacity bounds

        if val(mid_risk) > val(target_risk)
            min_efc = mid_efc
            upper_risk = mid_risk
        else
            max_efc = mid_efc
            lower_risk = mid_risk
        end

        capacity_gap = max_efc - min_efc

        params.verbose && println(
            "\n$(min_efc) $powerunit\t< EFC <\t$(max_efc) $powerunit\n",
            "$(upper_risk)\t> $(target_risk) >\t$(lower_risk)")

        # Return the bounds if they are within solution tolerance of each other

        if capacity_gap <= params.capacity_gap
            params.verbose && @info "Capacity bound gap within tolerance, stopping bisection."
            break
        end

    end

    return CapacityCreditResult{typeof(params), typeof(target_risk), P}(
        target_risk, min_efc, max_efc, efcs, risks)

end

function add_firmcapacity(
    sys::SystemModel{N,L,T,P,E}, region_shares::Vector{Tuple{String,Float64}}
) where {N,L,T,P,E}

    n_regions = length(sys.regions.names)
    n_region_allocs = length(region_shares)

    region_allocations = allocate_regions(sys.regions.names, region_shares)
    efc_gens = similar(region_allocations)

    new_gen(i::Int) = Generators{N,L,T,P}(
        ["_EFC_$i"], ["_EFC Calculation Dummy Generator"],
        zeros(Int, 1, N), zeros(1, N), ones(1, N))

    variable_gens = Generators{N,L,T,P}[]
    variable_region_gen_idxs = similar(sys.region_gen_idxs)

    ra_idx = 0

    for r in 1:n_regions

        gen_idxs = sys.region_gen_idxs[r]

        if (ra_idx < n_region_allocs) && (r == first(region_allocations[ra_idx+1]))

            ra_idx += 1

            variable_region_gen_idxs[r] = incr_range(gen_idxs, ra_idx-1, ra_idx)

            gen = new_gen(ra_idx)
            push!(variable_gens, gen)
            efc_gens[ra_idx] = (
                 first(gen_idxs) + ra_idx - 1,
                 last(region_allocations[ra_idx]))

        else

            variable_region_gen_idxs[r] = incr_range(gen_idxs, ra_idx)

        end

        push!(variable_gens, sys.generators[gen_idxs])

    end

    sys_variable = SystemModel(
        sys.regions, sys.interfaces,
        vcat(variable_gens...), variable_region_gen_idxs,
        sys.storages, sys.region_stor_idxs,
        sys.generatorstorages, sys.region_genstor_idxs,
        sys.lines, sys.interface_line_idxs, sys.timestamps)

    return sys_variable, efc_gens

end

function update_firmcapacity!(
    sys::SystemModel, gens::Vector{Tuple{Int,Float64}}, capacity::Int)

    for (g, share) in gens
        sys.generators.capacity[g, :] .= round(Int, share * capacity)
    end

end
