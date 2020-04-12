mutable struct ClassicMinimalAccumulator{N,L,T,E} <: ResultAccumulator{Minimal}

    lole::Float64
    eul::Float64

end

accumulatortype(::Classic, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicMinimalAccumulator{N,L,T,E}

accumulator(::Classic, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicMinimalAccumulator{N,L,T,E}(0., 0.)

function update!(
    acc::ClassicMinimalAccumulator,
    t::Int, lolp::Float64, eul::Float64
)

    acc.lole += lolp
    acc.eul += eul
    return

end

function finalize(
    results::Channel{ClassicMinimalAccumulator{N,L,T,E}},
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    lole = eul = 0.
    p2e = powertoenergy(P, L, T, E)

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
        Classic())

end
