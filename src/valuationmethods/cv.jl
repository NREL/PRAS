# TODO: Generalize beyond LOLE-equivalence
#       once other metrics supported
# TODO: Allow choice of calculation (copper plate or MC)
function efc(before::SystemDistributionSet,
             after::SystemDistributionSet,
             node::Int, nameplatecapacity::Float64;
             p::Float64=0.95,
             tol_mw::Float64=1.,
             iters::Int=10_000)

    @assert 0 < p < 1
    @assert tol_mw > 0

    loletarget = lole(simulate(after, iters))

    # # Switch to seperate process for finding min EFC to give LOLE=0
    # (loletarget == 0) && return efc0(
    #     before, node, nameplatecapacity
    # )

    # upperbound = loletarget * (1 + rtol)
    # lowerbound = loletarget * (1 - rtol)

    # Currently uses bisection.
    # Once REPRA runs across multiple HPC nodes, scale out and
    # use some kind of "multisection" method instead
    # (solve simultaneously at multiple points between fc_a and fc_b)
    lole_a = lole(simulate(before, iters))
    fc_a = 0.

    lole_b = lole(simulate(addfirmcapacity(
        before, node, nameplatecapacity), iters))
    fc_b = nameplatecapacity

    while true
        println("LOLE(", fc_b, ") < ",
                loletarget,
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
        p_a = pequal(loletarget, lole_a)
        p_b = pequal(loletarget, lole_b)
        if (p_a >= p) || (p_b >= p)
            return p_a > p_b ? lole_a : lole_b
        end

        # (abs(2 * (fc_b - fc_a) / (fc_a + fc_b)) <= rtol) && return fc_a
        # (lole_a <= upperbound) && return fc_a
        # (lole_b >= lowerbound) && return fc_b

        # Evaluate LOLE at midpoint
        fc_x = (fc_a + fc_b) / 2
        lole_x = lole(simulate(addfirmcapacity(
            before, node, fc_x), iters))

        # Tighten FC bounds
        if lole_x > loletarget
            fc_a = fc_x
            lole_a = lole_x
        else # lole_x <= loletarget
            fc_b = fc_x
            lole_b = lole_x
        end

    end

end


# """
# Use bisection to find lowest EFC where LOLE = 0,
# within tolerance `atol`
# """
# function efc0(basesystem::SystemDistributionSet,
#               node::Int, nameplatecapacity::Float64,
#               atol::Float64=0.00001,
#               iters::Int=10_000)

#     # As above, can likely extend this to "multisection"
#     # when running on the HPC
#     fc_a = 0
#     fc_b = nameplatecapacity

#     while true
#         println(fc_a, " < EFC < ", fc_b, "\n")
#         fc_x = (fc_a + fc_b) / 2
#         lole_x = lole(simulate(addfirmcapacity(
#             basesystem, node, fc_x), iters))
#         if lole_x == 0.
#             fc_b = fc_x
#         elseif 0. < lole_x < atol
#             return fc_x
#         else # lole_x >= atol
#             fc_a = fc_x
#         end
#     end

# end

function addfirmcapacity(x::SystemDistributionSet,
                         node::Int, capacity::Float64)

    old_distr = x.gen_distrs[node]
    new_distr = Generic(support(old_distr) .+ capacity,
                        Distributions.probs(old_distr))

    newdispatchabledistrs = copy(x.gen_distrs)
    newdispatchabledistrs[node] = new_distr

    return SystemDistributionSet(x.timestamps,
                                 newdispatchabledistrs,
                                 x.vgsamples,
                                 x.interface_labels,
                                 x.interface_distrs,
                                 x.loadsamples,
                                 x.hourwindow, x.daywindow)

end
