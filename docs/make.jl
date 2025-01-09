using Documenter
using PRASCore
#using Package2
#using Package3

# Generate the unified documentation
makedocs(
    sitename = "PRAS",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://nrel.github.io/PRAS/stable"
    ),
    modules = [PRASCore.Results,PRASCore.Systems],
    pages = [
        "Home" => "index.md",
        "PRASCore" => [
            "Overview" => "PRASCore/index.md",
            #"API Reference" => "PRASCore/api.md"
        ],
        # "Package2" => [
        #     "Overview" => "package2/index.md",
        #     "API Reference" => "package2/api.md"
        # ],
        # "Package3" => [
        #     "Overview" => "package3/index.md",
        #     "API Reference" => "package3/api.md"
        # ]
    ]
)

deploydocs(
    repo = "github.com/NREL/PRAS",
    devbranch = "main",
    push_preview = true
)