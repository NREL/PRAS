CapacityDistribution =
    DiscreteNonParametric{Int,Float64,Vector{Int},Vector{Float64}}

function (::Type{CapacityDistribution})(system::SystemModel, t::Int)

    capacities = system.generators.capacity[:, t]

    μ = system.generators.μ[:, t]
    λ = system.generators.λ[:, t]
    availabilities = μ ./ (μ .+ λ)

    result = spconv(capacities, availabilities)
    support(result) .-= colsum(system.regions.load, t)

    return result

end

function assess(distr::CapacityDistribution)

    xs = support(distr)
    ps = probs(distr)

    i = 1
    lolp = 0.
    eul = 0.

    while i <= length(xs)

       xs[i] >= 0 && break
       lolp += ps[i]
       eul -= ps[i] * xs[i]
       i += 1

    end

    return lolp, eul

end

function spconv(hvsraw::AbstractVector{Int}, hpsraw::AbstractVector{Float64})

    zeroidxs = hvsraw .!= 0
    hvs = hvsraw[zeroidxs]
    hps = hpsraw[zeroidxs]

    length(hvs) == 0 &&
        return DiscreteNonParametric([0], [1.], check_args=false)

    max_n = sum(hvs) + 1
    current_probs  = Vector{Float64}(undef, max_n)
    prev_probs     = Vector{Float64}(undef, max_n)
    current_values = Vector{Int}(undef, max_n)
    prev_values    = Vector{Int}(undef, max_n)

    current_n = 2
    current_values[1:current_n] = [0, hvs[1]]
    current_probs[1:current_n]  = [1 - hps[1], hps[1]]

    for (hv, hp) in zip(hvs[2:end], hps[2:end])
        current_values, current_probs, current_n, prev_values, prev_probs =
            spconv!(prev_values, prev_probs, hv, hp,
                    current_values, current_probs, current_n)
    end

    resize!(current_values, current_n)
    resize!(current_probs, current_n)
    nonzeroprob_idxs = findall(x -> x>0, current_probs)

    return DiscreteNonParametric(
        current_values[nonzeroprob_idxs],
        current_probs[nonzeroprob_idxs],
        check_args=false)

end

function spconv!(y_values::Vector{Int}, y_probs::Vector{Float64},
                 h_value::Int, h_prob::Float64,
                 x_values::Vector{Int}, x_probs::Vector{Float64}, nx::Int)

    h_q = 1 - h_prob

    ix = ixsh = 1
    iy = 0
    lastval = -1

    @inbounds while ix <= nx

        x = x_values[ix]
        xsh = x_values[ixsh] + h_value

        if lastval == x
            @fastmath y_probs[iy] += h_q * x_probs[ix]
            ix += 1

        elseif lastval == xsh
            @fastmath y_probs[iy] += h_prob * x_probs[ixsh]
            ixsh += 1

        elseif x == xsh
            iy += 1
            y_values[iy] = x
            @fastmath y_probs[iy] = h_q * x_probs[ix] + h_prob * x_probs[ixsh]
            lastval = x
            ix += 1
            ixsh += 1

        elseif x < xsh
            iy += 1
            y_values[iy] = x
            @fastmath y_probs[iy] = h_q * x_probs[ix]
            lastval = x
            ix += 1

        elseif xsh < x
            iy += 1
            y_values[iy] = xsh
            @fastmath y_probs[iy] = h_prob * x_probs[ixsh]
            lastval = xsh
            ixsh += 1

        end

    end

    @inbounds while ixsh <= nx
        iy += 1
        y_values[iy] = x_values[ixsh] + h_value
        @fastmath y_probs[iy] = h_prob * x_probs[ixsh]
        ixsh += 1
    end

    return y_values, y_probs, iy, x_values, x_probs

end
