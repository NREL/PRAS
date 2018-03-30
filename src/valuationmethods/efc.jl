struct EFC{
    M<:ReliabilityMetric,
    AM<:ReliabilityAssessmentMethod
} <: CapacityValuationMethod{M,AM} end

function assess(::Type{EFC{LOLE,AM}},
                sys_before::SystemDistributionSet{N1,T1,N2,T2,P,V},
                sys_after::SystemDistributionSet{N1,T1,N2,T2,P,V},
                nameplatecapacity::Float64;
                p::Float64=0.95,
                tol_mw::Float64=1.,
                iters::Int=10_000
                ) where {AM, N1, T1, N2, T2, P, V}

    node = 1 #TODO: Very problematic for non copperplate analyses!

    lole_target = lole(assess(AM, sys_after))

    lole_a = lole(assess(AM, sys_before))
    fc_a = 0.

    lole_b = lole(assess(AM, addfirmcapacity(sys_before, node, nameplatecapacity)))
    fc_b = nameplatecapacity

    while true

        println("LOLE(", fc_b, ") < ",
                lole_target,
                " <  LOLE(", fc_a, ")")
        println(lole_b, " < ",
                lole_target, " < ",
                lole_a)

        # Stopping conditions

        ## Return midpoint if bounds are within
        ## solution tolerance of each other
        (fc_b - fc_a < tol_mw) && return (fc_a + fc_b)/2

        ## If either bound LOLE exceeds the null hypothesis
        ## probability threshold, return the most probable bound
        p_a = pequal(lole_target, lole_a)
        p_b = pequal(lole_target, lole_b)
        if (p_a >= p) || (p_b >= p)
            return p_a > p_b ? lole_a : lole_b
        end

        # Evaluate LOLE at midpoint
        fc_x = (fc_a + fc_b) / 2
        lole_x = lole(assess(AM, addfirmcapacity(
            sys_before, node, fc_x)))

        # Tighten FC bounds
        if val(lole_x) > val(lole_target)
            fc_a = fc_x
            lole_a = lole_x
        else # lole_x <= lole_target
            fc_b = fc_x
            lole_b = lole_x
        end

    end

end
