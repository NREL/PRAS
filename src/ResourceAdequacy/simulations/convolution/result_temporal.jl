mutable struct ConvolutionTemporalAccumulator{N,L,T,E} <: ResultAccumulator{Temporal}

    lole::Float64
    lolps::Vector{Float64}

    eul::Float64
    euls::Vector{Float64}

end

accumulatortype(::Convolution, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ConvolutionTemporalAccumulator{N,L,T,E}

accumulator(::Convolution, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ConvolutionTemporalAccumulator{N,L,T,E}(0., zeros(N), 0., zeros(N))

function update!(
    acc::ConvolutionTemporalAccumulator,
    t::Int,  distr::CapacityDistribution
)

    lolp, eul = assess(distr)

    acc.lole += lolp
    acc.lolps[t] = lolp

    acc.eul += eul
    acc.euls[t] = eul

    return

end

function finalize(
    results::Channel{ConvolutionTemporalAccumulator{N,L,T,E}},
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    lole = eul = 0.
    lolps = zeros(N)
    euls = zeros(N)

    while accsremaining > 0

        acc = take!(results)

        lole += acc.lole
        lolps .+= acc.lolps

        eul += acc.eul
        euls .+= acc.euls

        accsremaining -= 1

    end

    close(results)

    p2e = conversionfactor(L,T,P,E)

    return TemporalResult(
        system.timestamps,
        LOLE{N,L,T}(lole, 0.), LOLP{L,T}.(lolps, 0.),
        EUE{N,L,T,E}(p2e * eul, 0.), EUE{1,L,T,E}.(p2e .* euls, 0.),
        Convolution())

end
