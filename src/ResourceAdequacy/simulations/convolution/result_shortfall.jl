struct ConvolutionShortfallAccumulator <: ResultAccumulator{Convolution,Shortfall}

    lolps::Vector{Float64}
    euls::Vector{Float64}

end

function merge!(
    x::ConvolutionShortfallAccumulator, y::ConvolutionShortfallAccumulator
)

    x.lolps .+= y.lolps
    x.euls .+= y.euls
    return

end

accumulatortype(::Convolution, ::Shortfall) = ConvolutionShortfallAccumulator

accumulator(::SystemModel{N}, ::Convolution, ::Shortfall) where {N} =
    ConvolutionShortfallAccumulator(zeros(N), zeros(N))

function record!(
    acc::ConvolutionShortfallAccumulator,
    t::Int,  distr::CapacityDistribution
)

    lolp, eul = assess(distr)
    acc.lolps[t] = lolp
    acc.euls[t] = eul
    return

end

function finalize(
    acc::ConvolutionShortfallAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    
    lole = sum(acc.lolps)

    p2e = conversionfactor(L,T,P,E)
    eues = acc.euls .* p2e
    eue = sum(eues)

    allzeros = zeros(length(acc.lolps))

    return ShortfallResult{N,L,T,E}(
        nothing, ["[PRAS] Entire System"], system.timestamps,
        lole, 0., [lole], [0.], acc.lolps, allzeros,
        reshape(acc.lolps, 1, :), reshape(allzeros, 1, :),
        reshape(eues, 1, :), 0., [0.], allzeros, reshape(allzeros, 1, :)
    )

end
