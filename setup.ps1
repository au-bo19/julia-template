# This script prepares this project on a Windows computer.
# For Linux and macOS, use setup.sh.
# You can run the script again at any time.
#
# Run the script from the project folder with this command:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#
# The script does these tasks:
#   1. It disconnects a new clone from the template repository.
#   2. It installs juliaup (if juliaup is missing) and the Julia version in
#      .julia-version. It also sets the Julia package manager to use the `git`
#      command of the computer. This is necessary for some git URLs.
#   3. It installs the Julia extension for VS Code (if the `code` command is
#      available).
#   4. It runs setup.jl. On the first run, setup.jl makes the project
#      environment. On subsequent runs, setup.jl installs the packages that the
#      project records.
#
# The template and all projects from the template use this same script.
# On a new computer, clone your project and run the script again.
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

# ---- Parameter for template maintainers --------------------------------------
# The name of the template repository. If the `origin` URL of a clone has this
# name at its end, the script removes `origin`. Thus a new project cannot push
# to the template. Use the same value in setup.sh.
$TemplateRepoName = 'julia-project-template'
# ------------------------------------------------------------------------------

function Step([string]$Message) { Write-Host "`n==> $Message" }
function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# This function runs a command and hides its output and its errors.
function Invoke-Quiet([scriptblock]$Command) {
    $ErrorActionPreference = 'Continue'
    & $Command 2>&1 | Out-Null
}

if (-not (Test-Path .julia-version)) { throw '.julia-version is missing' }
$JuliaVersion = "$(Get-Content -Raw .julia-version)".Trim()
if (-not $JuliaVersion) { throw '.julia-version is empty' }

# 1. Disconnect from the template -----------------------------------------------
# The script does this step only on the first run in a project.
# If there is a Project.toml file, the script does not change `origin`.
$detached = $false
if (-not (Test-Path Project.toml) -and (Test-Command git)) {
    $originUrl = "$(git config --get remote.origin.url)".Trim().TrimEnd('/') -replace '\.git$', ''
    if ($originUrl -cmatch ('[/:]' + [regex]::Escape($TemplateRepoName) + '$')) {
        Step 'Disconnecting this clone from the template repository'
        git remote remove origin
        if ($LASTEXITCODE -ne 0) { throw 'git could not remove the origin remote.' }
        $detached = $true
    }
}

# 2. Julia ----------------------------------------------------------------------
$freshJuliaup = $false
if (Test-Command juliaup) {
    Step "juliaup found; making sure Julia $JuliaVersion is installed"
    # `juliaup add` can show an error if the version is on the computer. Ignore
    # this error. The subsequent check stops the script if the version is missing.
    juliaup add $JuliaVersion
} else {
    Step "Installing juliaup and Julia $JuliaVersion"
    if (-not (Test-Command winget)) {
        throw 'winget is not available. Install Julia from the Microsoft Store or from https://julialang.org/install, then run this script again.'
    }
    winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'winget could not install Julia.' }
    # The Microsoft Store puts the `julia` and `juliaup` commands in this folder.
    $env:Path = "$env:LOCALAPPDATA\Microsoft\WindowsApps;$env:Path"
    if (-not (Test-Command juliaup)) {
        throw "Julia is installed, but this terminal cannot find it. Open a new terminal and run this script again."
    }
    juliaup add $JuliaVersion
    juliaup default $JuliaVersion
    $freshJuliaup = $true
}
julia "+$JuliaVersion" --version
if ($LASTEXITCODE -ne 0) {
    throw "Julia $JuliaVersion is not available. Check the value in .julia-version."
}

# In this folder, make the `julia` command start this version.
Invoke-Quiet { juliaup override unset }
juliaup override set $JuliaVersion

# Make the Julia package manager use the `git` command of the computer for git
# URLs. The git library in Julia does not read the git configuration of the
# computer. As a result, Julia can show a prompt for credentials. The
# environment variable applies to this script. The line in startup.jl applies
# to all subsequent Julia sessions on this computer (terminal, scripts, and
# VS Code).
if (Test-Command git) {
    $env:JULIA_PKG_USE_CLI_GIT = 'true'
    $startupDir = Join-Path (Join-Path $HOME '.julia') 'config'
    $startupFile = Join-Path $startupDir 'startup.jl'
    $hasLine = (Test-Path $startupFile) -and
        (Select-String -Path $startupFile -Pattern 'JULIA_PKG_USE_CLI_GIT' -Quiet)
    if (-not $hasLine) {
        New-Item -ItemType Directory -Force -Path $startupDir | Out-Null
        $line = 'haskey(ENV, "JULIA_PKG_USE_CLI_GIT") || (ENV["JULIA_PKG_USE_CLI_GIT"] = "true")  # The setup script added this line. Pkg uses the git command of the computer.'
        Add-Content -Path $startupFile -Encoding Ascii -Value @('', $line)
    }
}

# 3. VS Code extension ----------------------------------------------------------
Step 'Julia extension for VS Code'
if (Test-Command code) {
    code --install-extension julialang.language-julia
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Could not install it from here. VS Code will offer it when you open this folder.'
    }
} else {
    Write-Host "The 'code' command is not available in this terminal, so this was skipped."
    Write-Host 'VS Code will offer the extension when you open this folder (see .vscode/extensions.json).'
}

# 4. Project packages -----------------------------------------------------------
# setup.jl contains the package list and the package steps. Linux and macOS use
# the same file.
julia "+$JuliaVersion" setup.jl
if ($LASTEXITCODE -ne 0) { throw 'The package step did not complete. See the messages above.' }

# Summary -----------------------------------------------------------------------
Step 'Done'
Write-Host "Start Julia with this project's packages:   julia --project=."
if ($freshJuliaup) {
    Write-Host "Julia was just installed. If a new terminal cannot find 'julia', sign out and in again."
}
if ($detached) {
    Write-Host 'This clone no longer points at the template. To publish it as your own project,'
    Write-Host 'create an empty repository and run:'
    Write-Host '    git add -A'
    Write-Host '    git commit -m "Set up project"'
    Write-Host '    git remote add origin <your-repository-url>'
    Write-Host '    git push -u origin HEAD'
}
