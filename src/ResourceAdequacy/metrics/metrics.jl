function roundresults(x::ReliabilityMetric)

    if stderror(x) == 0

        v_rounded = @sprintf "%0.5f" val(x)
        s_rounded = "0"

    else

        s = Decimal(stderror(x))
        s_sigfigs = length(string(s.c))
        s_c = round(Int, s.c / 10^(s_sigfigs-1))
        s_q = s.q + s_sigfigs - 1
        s_rounded = string(Decimal(s.s, s_c, s_q))

        v = Decimal(val(x))
        v_c = round(Int, v.c / 10^(s_q - v.q))
        v_rounded = string(Decimal(v.s, v_c, s_q))

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
