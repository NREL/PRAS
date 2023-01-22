function makemapping(f::Function, vals::AbstractVector{T}) where T

    mappedidxs = Dict{Any,Int}()
    validxs = Vector{Int}(undef, length(vals))
    idx = 0

    for (i, val) in enumerate(vals)

        mappedval = f(val)

        if !haskey(mappedidxs, mappedval)
            idx += 1
            mappedidxs[mappedval] = idx
        end

        validxs[i] = mappedidxs[mappedval]

    end

    return validxs

end
