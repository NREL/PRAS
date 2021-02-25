struct ConvolutionSurplusAccumulator <: ResultAccumulator{Convolution,Surplus}

    surplus::Vector{Float64}

end

function merge!(
    x::ConvolutionSurplusAccumulator, y::ConvolutionSurplusAccumulator
)

    x.surplus .+= y.surplus
    return

end

accumulatortype(::Convolution, ::Surplus) = ConvolutionSurplusAccumulator

accumulator(::SystemModel{N}, ::Convolution, ::Surplus) where {N} =
    ConvolutionSurplusAccumulator(zeros(N))

function record!(
    acc::ConvolutionSurplusAccumulator,
    t::Int,  distr::CapacityDistribution
)

    acc.surplus[t] = surplus(distr)
    return

end

function finalize(
    acc::ConvolutionSurplusAccumulator,
    system::SystemModel{N,L,T,P,E},
) where {N,L,T,P,E}
    
    allzeros = zeros(length(acc.surplus))

    return SurplusResult{N,L,T,P}(
        nothing, ["__EntireSystem"], system.timestamps,
        reshape(acc.surplus, 1, :), allzeros, reshape(allzeros, 1, :)
    )

end
