# This script prepares this project on a Windows computer.
# You can run the script again at any time.
#
# Run the script from the project folder with this command:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#
# The script does these tasks:
#   1. It disconnects a new clone from the template repository. It deletes
#      the .git folder, so the folder is no longer a git repository.
#   2. It installs juliaup (if juliaup is missing), the Julia version in
#      .julia-version, and the `release` channel of juliaup. The language
#      server of VS Code uses the `release` channel. The script also sets the
#      Julia package manager to use the `git` command of the computer. This is
#      necessary for some git URLs.
#   3. It runs setup.jl. On the first run, setup.jl makes the project
#      environment. On subsequent runs, setup.jl installs the packages that the
#      project records. setup.jl also prepares the Julia REPL of VS Code (the
#      Julia version, Revise, the environment name in the julia> prompt, and
#      the keys that run code).
#   4. It installs two VS Code extensions (if the `code` command is
#      available): the Julia extension and the Julia Project Runner. The Julia
#      Project Runner makes Ctrl+Enter and Shift+Enter run code in a REPL that
#      belongs to the project of the file.
#
# The template and all projects from the template use this same script.
# On a new computer, clone your project and run the script again.
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

# ---- Parameter for template maintainers --------------------------------------
# The name of the template repository. If the `origin` URL of a clone has this
# name at its end, the script removes `origin`. Thus a new project cannot push
# to the template. Use the same value in setup.sh.
$TemplateRepoName = 'julia-template'
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
# The script does this step only on the first run in a new clone of the
# template. If there is a Project.toml file, the script does not change git.
# The step deletes the .git folder. Thus the folder is no longer a git
# repository: it has no remote, no branches, and no history of the template.
# The script skips this step in these conditions:
#   - The clone has commits that are not on `origin`.
#   - git config template.maintainer is true. (Set it in your clone of the
#     template: git config template.maintainer true)
$detached = $false
if (-not (Test-Path Project.toml) -and (Test-Path .git -PathType Container) -and
    (Test-Command git) -and
    "$(git config --bool --get template.maintainer)".Trim() -ne 'true') {
    $originUrl = "$(git config --get remote.origin.url)".Trim().TrimEnd('/') -replace '\.git$', ''
    if ($originUrl -cmatch ('[/:]' + [regex]::Escape($TemplateRepoName) + '$')) {
        $ErrorActionPreference = 'Continue'
        $unpushed = "$(git rev-list --count HEAD --not --remotes=origin 2>$null)".Trim()
        $ErrorActionPreference = 'Stop'
        if ($unpushed -and $unpushed -ne '0') {
            Step 'Not disconnecting from the template: this clone has commits that are not on origin'
        } else {
            Step 'Disconnecting this clone from the template repository (deleting .git)'
            # -Force is necessary because git makes some files in .git read-only.
            Remove-Item -LiteralPath .git -Recurse -Force
            if (Test-Path .git) { throw 'The script could not delete the .git folder.' }
            $detached = $true
        }
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

# The language server of the VS Code extension always uses the `release`
# channel. Without this channel, VS Code shows a prompt to install it.
if (-not ((juliaup status) -match '\brelease\b')) {
    Step 'Installing the juliaup release channel for the VS Code language server'
    juliaup add release
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Could not add the release channel. VS Code will offer to install it.'
    }
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

# 3. Project packages and VS Code preparation -----------------------------------
# setup.jl contains the package list and the package steps. Linux and macOS use
# the same file. setup.jl also builds .vscode\julia-project-runner.vsix.
julia "+$JuliaVersion" setup.jl
if ($LASTEXITCODE -ne 0) { throw 'The package step did not complete. See the messages above.' }

# 4. VS Code extensions ---------------------------------------------------------
$runnerVsix = Join-Path $PSScriptRoot '.vscode\julia-project-runner.vsix'
Step 'VS Code extensions: Julia and Julia Project Runner'
if (Test-Command code) {
    code --install-extension julialang.language-julia
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Could not install the Julia extension from here. VS Code will offer it when you open this folder.'
    }
    if (Test-Path $runnerVsix) {
        code --install-extension $runnerVsix --force
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Could not install the Julia Project Runner. Ctrl+Enter uses the keys of the Julia extension.'
        }
    }
} else {
    Write-Host "The 'code' command is not available in this terminal, so this was skipped."
    Write-Host 'Without the Julia Project Runner, Ctrl+Enter uses the keys of the Julia extension.'
    Write-Host 'To install it, run this script again in a terminal of VS Code.'
}
if (Test-Path $runnerVsix) { Remove-Item -LiteralPath $runnerVsix -Force }

# Summary -----------------------------------------------------------------------
Step 'Done'
Write-Host "Start Julia with this project's packages:   julia --project=."
if ($detached) {
    Write-Host 'This folder is no longer a git repository. To publish it as your own project,'
    Write-Host 'create an empty repository and run:'
    Write-Host '    git init -b main'
    Write-Host '    git add -A'
    Write-Host '    git commit -m "Set up project"'
    Write-Host '    git remote add origin <your-repository-url>'
    Write-Host '    git push -u origin HEAD'
}
Write-Host ''
Write-Host "IMPORTANT: Open a new terminal before you use 'julia'. If VS Code is open,"
Write-Host "close it and open it again (or run 'Developer: Reload Window')."
if ($freshJuliaup) {
    Write-Host "Julia was just installed. If a new terminal cannot find 'julia', sign out and in again."
}
