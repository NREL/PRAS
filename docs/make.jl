using Documenter
using PRASCore
using PRASFiles
using PRASCapacityCredits
using Plots, Literate

@info "Building example problems..."

# utility function from https://github.com/JuliaOpt/Convex.jl/blob/master/docs/make.jl
fix_math_md(content) = replace(content, r"\$\$(.*?)\$\$"s => s"```math\1```")
fix_suffix(filename) = replace(filename, ".jl" => ".md")
function postprocess(cont)
      """
      The source files for all examples can be found in [/examples](https://github.com/NREL/PRAS/examples/).
      """ * cont
end

example_path = joinpath(@__DIR__, "..","PRAS.jl","examples/")
build_path =  joinpath(@__DIR__, "src", "examples/")
files = readdir(example_path)
filter!(x -> endswith(x, ".jl"), files)
for file in files
      Literate.markdown(example_path * file, build_path; preprocess = fix_math_md, postprocess = postprocess, documenter = true, credit = true)
end

examples_nav = fix_suffix.("./examples/" .* files)

# Generate the unified documentation
makedocs(
    sitename = "PRAS",
    format = Documenter.HTML(
        prettyurls = true,
        canonical = "https://nrel.github.io/PRAS/stable"
    ),
    modules = [PRASCore, PRASFiles, PRASCapacityCredits],
    pages = [
        "Home" => "index.md",
        "Resource Adequacy" => "resource-adequacy.md",
        "Getting Started" => [
            "Installation" => "installation.md",
            "Quick start" => "getting-started.md",
        ],        
        "PRAS Components " => [
            "System Model Specification" => "PRAS/systemspec.md",
            "Simulation Specifications" => "PRAS/simulations.md",
            "Result Specifications" => "PRAS/results.md",
            "Capacity Credit Calculation" => "PRAS/capacity-credit.md",            
        ],
        ".pras File Format" => "SystemModel_HDF5_spec.md",
        "Examples" => examples_nav,
        "Extending PRAS" => "extending.md",
#        "Contributing" => "contributing.md",
        "Changelog" => "changelog.md",
        "API Reference" => [
            "PRASCore" => "PRASCore/api.md",
            "PRASFiles" => "PRASFiles/api.md",
            "PRASCapacityCredits" => "PRASCapacityCredits/api.md"
        ]
    ],
    checkdocs = :exports,
)

deploydocs(
    repo = "github.com/NREL/PRAS.git",
    devbranch = "ssh/docgen",
    push_preview = true,
)