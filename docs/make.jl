using Documenter
using LocalRegistry

makedocs(
    sitename = "LocalRegistry",
    format = Documenter.HTML(),
    warnonly = [:missing_docs],
    modules = [LocalRegistry],
    pages = [
        "Overview" => "index.md",
        "Advanced documentation" => [
            "Create registry" => "create_registry.md",
            "Delete package" => "delete_package.md",
            "Migration from general" => "migration_from_general.md",
            "Register" => "register.md",
            "Register CI" => "registry_ci.md",
            "Shared filesystem" => "shared_filesystem.md",
            "SSH keys" => "ssh_keys.md",
            "Subdir" => "subdir.md",
            "Troobleshooting general" => "troubleshooting_general.md"        
        ]
    ]
)


# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "github.com/GunnarFarneback/LocalRegistry.jl""
)=#
