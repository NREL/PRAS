function roundresults(x::ReliabilityMetric)

    if iszero(stderror(x))

        v_rounded = @sprintf "%0.5f" val(x)
        s_rounded = "0"

    else

        stderr_round = round(stderror(x), sigdigits=1)

        digits = floor(Int, log(10, stderr_round))

        rounded = round(val(x), digits=-digits)
        reduced = round(Int, rounded / 10. ^ digits)
        v_rounded = string(Decimal(Int(val(x) < 0), reduced, digits))

        s_rounded = string(decimal(stderr_round))

    end

    return v_rounded, s_rounded

end

include("LOLP.jl")
include("LOLE.jl")
include("EUE.jl")
include("ExpectedInterfaceFlow.jl")
include("ExpectedInterfaceUtilization.jl")

# Common getter methods
for T in [LOLP, LOLE, EUE, ExpectedInterfaceFlow, ExpectedInterfaceUtilization]

    @eval val(x::($T)) = x.val
    @eval stderror(x::($T)) = x.stderr

    @eval Base.isapprox(x::M, y::M) where {M<:($T)} =
        isapprox(x.val, y.val) &&
        isapprox(x.stderr, y.stderr)

end
