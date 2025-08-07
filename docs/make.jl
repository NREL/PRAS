using Documenter
using PRASCore
using PRASFiles
using PRASCapacityCredits

# Generate the unified documentation
makedocs(
    sitename = "PRAS",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://nrel.github.io/PRAS/stable"
    ),
    modules = [PRASCore, PRASFiles, PRASCapacityCredits],
    pages = [
        "Home" => "index.md",
        "Installation instructions" => "installation.md",
        "Resource adequacy" => "resource-adequacy.md",
        "Quick start" => "getting-started.md",
        "System model specification" => "SystemModel_HDF5_spec.md",
        "PRAS" => [
            "Introduction" => "PRAS/introduction.md",
            "Input System Specification" => "PRAS/inputs.md",
            "Simulation Specifications" => "PRAS/simulations.md",
            "Result Specifications" => "PRAS/results.md",
            "Capacity Credit Calculation" => "PRAS/capacity-credit.md",
            "Extending PRAS" => "PRAS/extending.md",
        ],
        "API Reference" => [
            "PRASCore" => "PRASCore/api.md",
            "PRASFiles" => "PRASFiles/api.md",
            "PRASCapacityCredits" => "PRASCapacityCredits/api.md"
        ]
    ],
    checkdocs = :exports,
    warnonly = true,
)

deploydocs(
    repo = "github.com/NREL/PRAS.git",
    devbranch = "main",
    push_preview = true
)