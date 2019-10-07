struct EFC <: CapacityValuationMethod
    nameplatecapacity::Float64
    p::Float64
    tol_mw::Float64
    nodes::DiscreteNonParametric{Int,Float64,Vector{Int}}
end

function RA.assess(params::EFC,
                   metric::Type{<:RA.ReliabilityMetric},
                   extractionspec::RA.ExtractionSpec,
                   simulationspec::RA.SimulationSpec,
                   resultspec::RA.ResultSpec,
                   sys_before::S, sys_after::S, seed::UInt=rand(UInt)) where {S <: RA.SystemModel}

    metric_target = metric(RA.assess(extractionspec, simulationspec, resultspec, sys_after, seed))

    metric_a = metric(RA.assess(extractionspec, simulationspec, resultspec, sys_before, seed))
    fc_a = 0.

    metric_b = metric(RA.assess(extractionspec, simulationspec, resultspec,
        addfirmcapacity(sys_before, params.nodes, params.nameplatecapacity), seed))
    fc_b = params.nameplatecapacity

    while true

        println("(", fc_b, ", ", metric_b, ")",
                " < ", metric_target, " < ",
                "(", fc_a, ", ", metric_a, ")")

        # Stopping conditions

        ## Return midpoint if bounds are within solution tolerance of each other
        if fc_b - fc_a < params.tol_mw
            println("Capacity difference within tolerance, stopping.")
            return (fc_a + fc_b)/2
        end

        ## If either bound exceeds the null hypothesis
        ## probability threshold, return the most probable bound
        p_a = pequal(metric_target, metric_a)
        p_b = pequal(metric_target, metric_b)
        if (p_a >= params.p) || (p_b >= params.p)
            println("Equality probability within tolerance, stopping.")
            return p_a > p_b ? fc_a : fc_b
        end

        # Evaluate metric at midpoint
        fc_x = (fc_a + fc_b) / 2
        metric_x = metric(RA.assess(
            extractionspec,
            simulationspec,
            resultspec,
            addfirmcapacity(sys_before, params.nodes, fc_x), seed))

        # Tighten FC bounds
        if RA.val(metric_x) > RA.val(metric_target)
            fc_a = fc_x
            metric_a = metric_x
        else # metric_x <= metric_target
            fc_b = fc_x
            metric_b = metric_x
        end

    end

end
