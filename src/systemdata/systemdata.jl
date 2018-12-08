# Immutable asset specifications

abstract type AssetSpec{T<:Real} end

struct DispatchableGeneratorSpec{T<:Real} <: AssetSpec{T}
    capacity::T
    λ::T
    μ::T
end

struct StorageDeviceSpec{T<:Real} <: AssetSpec{T}
    capacity::T
    energy::T
    decayrate::T
    λ::T
    μ::T
end

struct LineSpec{T<:Real} <: AssetSpec{T}
    capacity::T
    λ::T
    μ::T
end

include("SystemModel.jl")
include("SystemInputStateDistribution.jl")
include("SystemOutputStateSample.jl")
include("SystemOutputStateSummary.jl")
