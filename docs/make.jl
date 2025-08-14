using Documenter
using PRASCore
using PRASFiles
using PRASCapacityCredits

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