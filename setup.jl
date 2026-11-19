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
#   5. It changes the VS Code keys that run code (Ctrl+Enter, Shift+Enter,
#      Alt+Enter, Alt+Shift+Enter). The keys run the code in a REPL that belongs
#      to the project of the file. This applies to all VS Code windows of this
#      user.
#   6. It builds the Julia Project Runner extension for VS Code from
#      .vscode/julia-project-runner. The setup script installs it. The keys of
#      step 5 use this extension.

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

# 5. VS Code keys ---------------------------------------------------------------
# The Julia extension runs code in one REPL per VS Code window. This step adds
# four keys to the keybindings.json file of the VS Code user. Each key calls the
# Julia Project Runner extension (see .vscode/julia-project-runner/extension.js):
#   - If the REPL belongs to a different project than the file, the extension
#     restarts the REPL in the project of the file. Thus the variables of one
#     project never carry over into a different project.
#   - Then the extension runs the code with the command of the Julia extension.
# The keys apply only when the extension is active. Without the extension, the
# keys of the Julia extension apply.
#
# The keys are between two julia-template comments. Each run of the script
# replaces these lines. To remove the keys, delete these lines.
const KEYS_MARKER = "julia-template: run code in the project of the file"

function vscode_user_dirs()
    home = homedir()
    bases = if Sys.iswindows()
        [get(ENV, "APPDATA", joinpath(home, "AppData", "Roaming"))]
    elseif Sys.isapple()
        [joinpath(home, "Library", "Application Support")]
    else
        [get(ENV, "XDG_CONFIG_HOME", joinpath(home, ".config")),
         joinpath(home, ".var", "app", "com.visualstudio.code", "config")]  # Flatpak
    end
    dirs = [joinpath(base, app, "User") for base in bases
            for app in ("Code", "Code - Insiders", "VSCodium")]
    found = filter(isdir, dirs)
    return isempty(found) ? [joinpath(first(bases), "Code", "User")] : found
end

# The keys as JSON lines. If `more` is true, a comma follows the last key,
# because other keys follow in the list.
function keys_block(more::Bool)
    when = "editorTextFocus && activeEditor != workbench.editor.notebook && " *
           "editorLangId in julia.supportedLanguageIds && juliaProjectRunner.active"
    keys = [("ctrl+enter", "executeCodeBlockOrSelection"),
            ("shift+enter", "executeCodeBlockOrSelectionAndMove"),
            ("alt+enter", "executeCell"),
            ("shift+alt+enter", "executeCellAndMove")]
    lines = ["  // >>> $KEYS_MARKER (setup.jl of the Julia project template added these keys)"]
    for (i, (key, command)) in enumerate(keys)
        comma = (i < length(keys) || more) ? "," : ""
        append!(lines, [
            "  {",
            "    \"key\": \"$key\",",
            "    \"command\": \"juliaProjectRunner.run\",",
            "    \"args\": \"language-julia.$command\",",
            "    \"when\": \"$when\"",
            "  }$comma"])
    end
    push!(lines, "  // <<< $KEYS_MARKER")
    return join(lines, "\n")
end

# Returns the index of the next character that is not white space or a comment.
function skip_jsonc_trivia(text, i)
    while i <= lastindex(text)
        if isspace(text[i])
            i = nextind(text, i)
        elseif startswith(SubString(text, i), "//")
            j = findnext('\n', text, i)
            i = j === nothing ? lastindex(text) + 1 : j + 1
        elseif startswith(SubString(text, i), "/*")
            j = findnext("*/", text, i)
            i = j === nothing ? lastindex(text) + 1 : last(j) + 1
        else
            return i
        end
    end
    return i
end

for dir in vscode_user_dirs()
    file = joinpath(dir, "keybindings.json")
    try
        old = isfile(file) ? read(file, String) : ""
        # Remove the keys of a previous run.
        text = replace(old, r"(?ms)^[ \t]*// >>> julia-template:.*?^[ \t]*// <<< julia-template:[^\n]*\n?" => "")
        i = skip_jsonc_trivia(text, firstindex(text))
        if i > lastindex(text)
            # The file is missing, empty, or has only comments.
            new = text * (isempty(text) || endswith(text, '\n') ? "" : "\n") *
                  "[\n" * keys_block(false) * "\n]\n"
        elseif text[i] == '['
            k = skip_jsonc_trivia(text, i + 1)
            empty_list = k <= lastindex(text) && text[k] == ']'
            rest = text[i+1:end]
            new = text[1:i] * "\n" * keys_block(!empty_list) *
                  (startswith(rest, r"\r?\n") ? "" : "\n") * rest
        else
            @warn "$file does not contain a list. Add the keys manually (see the README)."
            continue
        end
        new == old && continue
        mkpath(dir)
        write(file, new)
        println("\n==> Set the VS Code keys Ctrl+Enter, Shift+Enter, Alt+Enter, and Alt+Shift+Enter (see $file)")
    catch err
        @warn "Could not change the VS Code keys in $file" exception = err
    end
end

# 6. Julia Project Runner extension ---------------------------------------------
# A .vsix file is a zip file. This step writes the zip file without compression,
# so that no zip program is necessary. The setup script installs the file with
# `code --install-extension` and then deletes it.
function crc32(data::AbstractVector{UInt8})
    table = map(0:255) do n
        c = UInt32(n)
        for _ in 1:8
            c = isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1
        end
        c
    end
    crc = 0xffffffff
    for byte in data
        crc = table[((crc ⊻ byte) & 0xff) + 1] ⊻ (crc >> 8)
    end
    return ~crc
end

function write_zip(path, entries)
    out = IOBuffer()
    central = IOBuffer()
    for (name, data) in entries
        offset = position(out)
        n = codeunits(name)
        c = crc32(data)
        size = UInt32(length(data))
        # Local file header: version 2.0, no flags, no compression, date 1980-01-01.
        write(out, htol(0x04034b50), htol(UInt16(20)), htol(UInt16(0)), htol(UInt16(0)),
              htol(UInt16(0)), htol(UInt16(0x21)), htol(c), htol(size), htol(size),
              htol(UInt16(length(n))), htol(UInt16(0)), n, data)
        # Central directory entry.
        write(central, htol(0x02014b50), htol(UInt16(20)), htol(UInt16(20)), htol(UInt16(0)),
              htol(UInt16(0)), htol(UInt16(0)), htol(UInt16(0x21)), htol(c), htol(size), htol(size),
              htol(UInt16(length(n))), htol(UInt16(0)), htol(UInt16(0)), htol(UInt16(0)),
              htol(UInt16(0)), htol(UInt32(0)), htol(UInt32(offset)), n)
    end
    directory = take!(central)
    directory_offset = position(out)
    write(out, directory, htol(0x06054b50), htol(UInt16(0)), htol(UInt16(0)),
          htol(UInt16(length(entries))), htol(UInt16(length(entries))),
          htol(UInt32(length(directory))), htol(UInt32(directory_offset)), htol(UInt16(0)))
    write(path, take!(out))
end

let source = joinpath(@__DIR__, ".vscode", "julia-project-runner"),
    vsix = joinpath(@__DIR__, ".vscode", "julia-project-runner.vsix")

    if isdir(source)
        package_json = read(joinpath(source, "package.json"), String)
        version = match(r"\"version\"\s*:\s*\"([^\"]+)\"", package_json)[1]
        vsix_manifest = """
            <?xml version="1.0" encoding="utf-8"?>
            <PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
              <Metadata>
                <Identity Language="en-US" Id="julia-project-runner" Version="$version" Publisher="julia-template"/>
                <DisplayName>Julia Project Runner</DisplayName>
                <Description xml:space="preserve">Runs Julia code in a REPL that belongs to the project of the file.</Description>
              </Metadata>
              <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
              <Dependencies/>
              <Assets>
                <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
              </Assets>
            </PackageManifest>
            """
        content_types = """
            <?xml version="1.0" encoding="utf-8"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension=".json" ContentType="application/json"/>
              <Default Extension=".js" ContentType="application/javascript"/>
              <Default Extension=".vsixmanifest" ContentType="text/xml"/>
            </Types>
            """
        entries = Pair{String,Vector{UInt8}}[
            "[Content_Types].xml" => Vector{UInt8}(content_types),
            "extension.vsixmanifest" => Vector{UInt8}(vsix_manifest)]
        for name in sort(readdir(source))
            push!(entries, "extension/$name" => read(joinpath(source, name)))
        end
        write_zip(vsix, entries)
        println("\n==> Built the Julia Project Runner extension $version for VS Code")
    end
end
