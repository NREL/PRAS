mutable struct ConvolutionMinimalAccumulator{N,L,T,E} <: ResultAccumulator{Minimal}

    lole::Float64
    eul::Float64

end

accumulatortype(::Convolution, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ConvolutionMinimalAccumulator{N,L,T,E}

accumulator(::Convolution, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ConvolutionMinimalAccumulator{N,L,T,E}(0., 0.)

function update!(
    acc::ConvolutionMinimalAccumulator,
    t::Int, distr::CapacityDistribution
)

    lolp, eul = assess(distr)
    acc.lole += lolp
    acc.eul += eul
    return

end

function finalize(
    results::Channel{ConvolutionMinimalAccumulator{N,L,T,E}},
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    lole = eul = 0.
    p2e = conversionfactor(L, T, P, E)

    while accsremaining > 0
        acc = take!(results)
        lole += acc.lole
        eul += acc.eul
        accsremaining -= 1
    end

    close(results)

    return MinimalResult(
        LOLE{N,L,T}(lole, 0.),
        EUE{N,L,T,E}(eul * p2e, 0.),
        Convolution())

end
