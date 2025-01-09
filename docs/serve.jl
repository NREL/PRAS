using LiveServer
using Pkg

# Develop all packages
for pkg in readdir("../packages")
    pkg_path = joinpath("..", "packages", pkg)
    isdir(pkg_path) || continue
    Pkg.develop(PackageSpec(path=pkg_path))
end

# Build docs
include("make.jl")

# Serve documentation
serve(dir="build")