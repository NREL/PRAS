using LiveServer
using Pkg

# Develop all packages
for pkg in ["PRASCore.jl", "PRASFiles.jl", "PRASCapacityCredits.jl"]
    pkg_path = joinpath("..", pkg)
    isdir(pkg_path) || continue
    Pkg.develop(PackageSpec(path=pkg_path))
end

# Build docs
include("make.jl")

# Serve documentation
serve(dir="build")