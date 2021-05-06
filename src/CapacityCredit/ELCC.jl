struct ELCC{M} <: CapacityValuationMethod{M}

    capacity_max::Int
    capacity_gap::Int
    p_value::Float64
    regions::Vector{Tuple{String,Float64}}

    function ELCC{M}(
        capacity_max::Int, regions::Vector{Pair{String,Float64}};
        capacity_gap::Int=1, p_value::Float64=0.05) where M

        @assert capacity_max > 0
        @assert capacity_gap > 0
        @assert 0 < p_value < 1
        @assert sum(x.second for x in regions) ≈ 1.0

        return new{M}(capacity_max, capacity_gap, p_value, Tuple.(regions))

    end

end

function ELCC{M}(
    capacity_max::Int, region::String; kwargs...
) where M
    return ELCC{M}(capacity_max, [region=>1.0]; kwargs...)
end

function assess(params::ELCC{M},
                simulationspec::SimulationSpec,
                resultspec::ResultSpec,
                sys_baseline::S, sys_augmented::S;
                verbose::Bool=true
) where {S <: SystemModel, M <: ReliabilityMetric}

    _, powerunit, _ = unitsymbol(sys_baseline)

    regionnames = sys_baseline.regions.names
    regionnames != sys_augmented.regions.names &&
        error("Systems provided do not have matching regions")

    target_metric = M(assess(simulationspec, resultspec, sys_baseline))

    elcc_regions, base_load, sys_variable =
        copy_load(sys_augmented, params.regions)

    lower_bound = 0
    lower_bound_metric = M(assess(simulationspec, resultspec, sys_variable))

    upper_bound = params.capacity_max
    update_load!(sys_variable, elcc_regions, base_load, upper_bound)
    upper_bound_metric = M(assess(simulationspec, resultspec, sys_variable))

    while true

        verbose && println(
            "\n$(lower_bound) $powerunit\t< ELCC <\t$(upper_bound) $powerunit\n",
            "$(lower_bound_metric)\t< $(target_metric) <\t$(upper_bound_metric)")

        midpoint = div(lower_bound + upper_bound, 2)
        capacity_gap = upper_bound - lower_bound

        # Stopping conditions

        ## Return the bounds if they are within solution tolerance of each other
        if capacity_gap <= params.capacity_gap
            @info "Capacity bound gap within tolerance, stopping bisection."
            return lower_bound, upper_bound
        end

        # If the null hypothesis upper_bound_metric !>= lower_bound_metric
        # cannot be rejected, terminate and return the loose bounds
        pval = pvalue(lower_bound_metric, upper_bound_metric)
        if pval >= params.p_value
            @warn "Gap between upper and lower bound risk metrics is not " *
                  "statistically significant (p_value=$pval), stopping bisection. " *
                  "The gap between capacity bounds is $(capacity_gap) $powerunit, " *
                  "while the target stopping gap was $(params.capacity_gap) $powerunit."
            return lower_bound, upper_bound
        end

        # Evaluate metric at midpoint
        update_load!(sys_variable, elcc_regions, base_load, midpoint)
        midpoint_metric = M(assess(simulationspec, resultspec, sys_variable))

        # Tighten capacity bounds
        if val(midpoint_metric) < val(target_metric)
            lower_bound = midpoint
            lower_bound_metric = midpoint_metric
        else # midpoint_metric <= target_metric
            upper_bound = midpoint
            upper_bound_metric = midpoint_metric
        end

    end

end

function copy_load(
    sys::SystemModel{N,L,T,P,E},
    region_shares::Vector{Tuple{String,Float64}}
) where {N,L,T,P,E}

    region_allocations = allocate_regions(sys.regions.names, region_shares)

    new_regions = Regions{N,P}(sys.regions.names, copy(sys.regions.load))

    return region_allocations, sys.regions.load, SystemModel(
        new_regions, sys.interfaces,
        sys.generators, sys.region_gen_idxs,
        sys.storages, sys.region_stor_idxs,
        sys.generatorstorages, sys.region_genstor_idxs,
        sys.lines, sys.interface_line_idxs, sys.timestamps)

end

function update_load!(
    sys::SystemModel,
    region_shares::Vector{Tuple{Int,Float64}},
    load_base::Matrix{Int},
    load_increase::Int
)
    for (r, share) in region_shares
        sys.regions.load[r, :] .= load_base[r, :] .+
                                  round(Int, share * load_increase)
    end

end
