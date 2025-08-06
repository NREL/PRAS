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
        "Installation" => "installation.md",
        "Getting Started" => "getting-started.md",
        "PRASCore" => [
            "Overview" => "PRASCore/index.md",
            "API Reference" => "PRASCore/api.md"
        ],
        "PRASFiles" => [
            "Overview" => "PRASFiles/index.md",
            "API Reference" => "PRASFiles/api.md"
        ],
        "PRASCapacityCredits" => [
            "Overview" => "PRASCapacityCredits/index.md",
            "API Reference" => "PRASCapacityCredits/api.md"
        ]
    ],
    checkdocs = :exports,
    warnonly = true,
)

deploydocs(
    repo = "github.com/NREL/PRAS",
    devbranch = "main",
    push_preview = true
)