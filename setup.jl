# This script prepares the package environment of this project.
# setup.sh (Linux and macOS) and setup.ps1 (Windows) run this script.
# If Julia is on your computer, you can also run it directly: julia setup.jl
#
# The script does these tasks:
#   1. On the first run in a project, it makes the project environment. On
#      subsequent runs, it installs the packages that the project records.
#   2. It writes the Julia version of .julia-version into .vscode/settings.json.
#      Thus the Julia REPL of VS Code uses the same version as the project.
#   3. It installs Revise in the default environment of this Julia version. The
#      Julia REPL of VS Code loads Revise. Without Revise, VS Code shows a
#      prompt to install it.
#   4. It makes the julia> prompt show the active environment, for example
#      "(my-project) julia> ". This applies to all Julia sessions on this
#      computer.

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

# 1. Project packages -----------------------------------------------------------
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

# 2. Julia version for VS Code --------------------------------------------------
let version_file = joinpath(@__DIR__, ".julia-version"),
    settings_file = joinpath(@__DIR__, ".vscode", "settings.json")

    if isfile(version_file) && isfile(settings_file)
        version = strip(read(version_file, String))
        old = read(settings_file, String)
        new = replace(old, r"\"julia\.executablePath\"\s*:\s*\"[^\"]*\"" =>
                           "\"julia.executablePath\": \"julia +$version\"")
        if new != old
            write(settings_file, new)
            println("\n==> Set the Julia version for VS Code to $version in .vscode/settings.json")
        end
    end
end

# 3. Revise ---------------------------------------------------------------------
# The default environment (for example @v1.13) is on the load path of all
# projects. Thus the REPL of VS Code can load Revise in all projects, but the
# projects do not record Revise.
let default_env = "v$(VERSION.major).$(VERSION.minor)"
    Pkg.activate(default_env; shared = true, io = devnull)
    if !haskey(Pkg.project().dependencies, "Revise")
        println("\n==> Installing Revise in the default environment @$default_env")
        try
            Pkg.add("Revise")
        catch err
            @warn "Could not install Revise. VS Code will offer to install it." exception = err
        end
    end
    Pkg.activate(@__DIR__; io = devnull)
end

# 4. Environment name in the julia> prompt --------------------------------------
# The script writes project_prompt.jl into the Julia config folder and adds one
# line to startup.jl that loads it. To remove the feature, delete that line.
let config_dir = joinpath(first(DEPOT_PATH), "config"),
    prompt_file = joinpath(config_dir, "project_prompt.jl"),
    startup_file = joinpath(config_dir, "startup.jl")

    prompt_code = raw"""
    # The setup script of the Julia project template wrote this file. The script
    # replaces this file each time that it runs.
    #
    # The julia> prompt shows the active environment, the same as the pkg> prompt:
    #   (my-project) julia>    the environment of a project folder
    #   (@v1.13) julia>        the default environment of the computer
    # To remove the feature, delete the line in startup.jl that loads this file.
    atreplinit() do repl
        hasfield(typeof(repl), :interface) || return
        try
            REPL = parentmodule(typeof(repl))
            isdefined(repl, :interface) || (repl.interface = REPL.setup_interface(repl))
            repl.interface.modes[1].prompt = function ()
                project = Base.active_project()
                project === nothing && return "julia> "
                dir = dirname(project)
                name = basename(dir)
                depot_envs = [normpath(joinpath(depot, "environments")) for depot in DEPOT_PATH]
                normpath(dirname(dir)) in depot_envs && (name = "@" * name)
                return "($name) julia> "
            end
        catch err
            @warn "project_prompt.jl could not change the julia> prompt" exception = err
        end
    end
    """
    mkpath(config_dir)
    write(prompt_file, prompt_code)

    startup_line = """isfile(joinpath(@__DIR__, "project_prompt.jl")) && include(joinpath(@__DIR__, "project_prompt.jl"))  # The setup script added this line. The julia> prompt shows the active environment."""
    if !(isfile(startup_file) && occursin("project_prompt.jl", read(startup_file, String)))
        open(startup_file, "a") do io
            print(io, "\n", startup_line, "\n")
        end
        println("\n==> The julia> prompt now shows the active environment (see $startup_file)")
    end
end
