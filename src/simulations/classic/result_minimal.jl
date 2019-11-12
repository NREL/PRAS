mutable struct ClassicMinimalAccumulator{N,L,T,E} <: ResultAccumulator{Minimal}

    lole::Float64
    eue::Float64

end

accumulatortype(::Classic, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicMinimalAccumulator{N,L,T,E}

accumulator(::Classic, ::Minimal, ::SystemModel{N,L,T,P,E}) where {N,L,T,P,E} = 
    ClassicMinimalAccumulator{N,L,T,E}(0., 0.)

function update!(
    acc::ClassicMinimalAccumulator,
    t::Int, lolp::Float64, eue::Float64
)

    acc.lole += lolp
    acc.eue += eue
    return

end

function finalize(
    results::Channel{ClassicMinimalAccumulator{N,L,T,E}},
    system::SystemModel{N,L,T,P,E},
    accsremaining::Int
) where {N,L,T,P,E}

    lole = eue = 0.

    while accsremaining > 0
        acc = take!(results)
        lole += acc.lole
        eue += acc.eue
        accsremaining -= 1
    end

    close(results)

    return MinimalResult(
        LOLE{N,L,T}(lole, 0.),
        EUE{N,L,T,E}(eue, 0.),
        Classic())

end
