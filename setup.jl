# This script prepares the package environment of this project.
# setup.sh (Linux and macOS) and setup.ps1 (Windows) run this script.
# If Julia is on your computer, you can also run it directly: julia setup.jl
#
# On the first run in a project, the script makes the project environment.
# On subsequent runs, it installs the packages that the project records.

# ---- Parameter for template maintainers --------------------------------------
# The script adds these packages on the first run in a project. This occurs
# when there is no Project.toml file. Each entry is a package name from the
# General registry or the git URL of a package that is not in the registry.
const DEFAULT_PACKAGES = [
    "Arrow",
    "BenchmarkTools",
    "Chain",
    "DataFrames",
    "Dates",
    "DBInterface"
]
# ------------------------------------------------------------------------------

using Pkg

is_git_url(entry) = occursin("://", entry) || startswith(entry, "git@")

Pkg.activate(@__DIR__)

if isfile(joinpath(@__DIR__, "Project.toml"))
    println("\n==> Restoring the packages recorded in Project.toml and Manifest.toml")
    Pkg.instantiate()
else
    println("\n==> Creating the project environment with: ", join(DEFAULT_PACKAGES, " "))
    Pkg.add([
        is_git_url(entry) ? Pkg.PackageSpec(url = entry) : Pkg.PackageSpec(name = entry)
        for entry in DEFAULT_PACKAGES
    ])
end

Pkg.precompile()
