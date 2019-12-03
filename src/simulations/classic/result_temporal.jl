mutable struct ClassicTemporalAccumulator{N,L,T,E} <: ResultAccumulator{Temporal}

    lole::Float64
    lolps::Vector{Float64}

    eue::Float64
    eues::Vector{Float64}

end

accumulatortype(::Classic, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicTemporalAccumulator{N,L,T,E}

accumulator(::Classic, ::Temporal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicTemporalAccumulator{N,L,T,E}(0., zeros(N), 0., zeros(N))

function update!(
    acc::ClassicTemporalAccumulator,
    t::Int, lolp::Float64, eue::Float64
)

    acc.lole += lolp
    acc.lolps[t] = lolp

    acc.eue += eue
    acc.eues[t] = eue

    return

end

function finalize(
    results::Channel{ClassicTemporalAccumulator{N,L,T,E}},
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    lole = eue = 0.
    lolps = zeros(N)
    eues = zeros(N)

    while accsremaining > 0

        acc = take!(results)

        lole += acc.lole
        lolps .+= acc.lolps

        eue += acc.eue
        eues .+= acc.eues

        accsremaining -= 1

    end

    close(results)

    return TemporalResult(
        system.timestamps,
        LOLE{N,L,T}(lole, 0.), LOLP{L,T}.(lolps, 0.),
        EUE{N,L,T,E}(eue, 0.), EUE{1,L,T,E}.(eues, 0.),
        Classic())

end
