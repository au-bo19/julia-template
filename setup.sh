#!/usr/bin/env bash
# This script prepares this project on a Linux or macOS computer.
# sudo is not necessary.
# You can run the script again at any time.
#
# The script does these tasks:
#   1. It disconnects a new clone from the template repository. It deletes
#      the .git folder, so the folder is no longer a git repository.
#   2. It installs juliaup (if juliaup is missing), the Julia version in
#      .julia-version, and the `release` channel of juliaup. The language
#      server of VS Code uses the `release` channel. The script also sets the
#      Julia package manager to use the `git` command of the computer. This is
#      necessary for some git URLs.
#   3. It installs the Julia extension for VS Code (if the `code` command is
#      available).
#   4. It runs setup.jl. On the first run, setup.jl makes the project
#      environment. On subsequent runs, setup.jl installs the packages that the
#      project records. setup.jl also prepares the Julia REPL of VS Code (the
#      Julia version, Revise, and the environment name in the julia> prompt).
#
# The template and all projects from the template use this same script.
# On a new computer, clone your project and run the script again.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# ---- Parameter for template maintainers --------------------------------------
# The name of the template repository. If the `origin` URL of a clone has this
# name at its end, the script removes `origin`. Thus a new project cannot push
# to the template. Use the same value in setup.ps1.
TEMPLATE_REPO_NAME="julia-template"
# ------------------------------------------------------------------------------

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ -f .julia-version ] || fail ".julia-version is missing"
JULIA_VERSION="$(tr -d '[:space:]' < .julia-version)"
[ -n "$JULIA_VERSION" ] || fail ".julia-version is empty"

# 1. Disconnect from the template -----------------------------------------------
# The script does this step only on the first run in a new clone of the
# template. If there is a Project.toml file, the script does not change git.
# The step deletes the .git folder. Thus the folder is no longer a git
# repository: it has no remote, no branches, and no history of the template.
# The script skips this step in these conditions:
#   - The clone has commits that are not on `origin`.
#   - git config template.maintainer is true. (Set it in your clone of the
#     template: git config template.maintainer true)
detached=no
if [ ! -f Project.toml ] && [ -d .git ]   && [ "$(git config --bool --get template.maintainer 2>/dev/null || true)" != true ]   && origin_url="$(git remote get-url origin 2>/dev/null)"; then
  origin_url="${origin_url%/}"
  origin_url="${origin_url%.git}"
  case "$origin_url" in
    */"$TEMPLATE_REPO_NAME" | *:"$TEMPLATE_REPO_NAME")
      if [ "$(git rev-list --count HEAD --not --remotes=origin 2>/dev/null || echo 0)" != 0 ]; then
        step "Not disconnecting from the template: this clone has commits that are not on origin"
      else
        step "Disconnecting this clone from the template repository (deleting .git)"
        rm -rf .git
        [ ! -e .git ] || fail "could not delete the .git folder"
        detached=yes
      fi
      ;;
  esac
fi

# 2. Julia ----------------------------------------------------------------------
export PATH="$HOME/.juliaup/bin:$PATH"
fresh_juliaup=no
if command -v juliaup >/dev/null 2>&1; then
  step "juliaup found; making sure Julia $JULIA_VERSION is installed"
  # `juliaup add` can show an error if the version is on the computer. Ignore
  # this error. The subsequent check stops the script if the version is missing.
  juliaup add "$JULIA_VERSION" || true
else
  step "Installing juliaup and Julia $JULIA_VERSION"
  curl -fsSL https://install.julialang.org | sh -s -- --yes --default-channel "$JULIA_VERSION"
  fresh_juliaup=yes
fi
julia "+$JULIA_VERSION" --version \
  || fail "Julia $JULIA_VERSION is not available. Check the value in .julia-version."

# The language server of the VS Code extension always uses the `release`
# channel. Without this channel, VS Code shows a prompt to install it.
if ! juliaup status 2>/dev/null | grep -qw release; then
  step "Installing the juliaup release channel for the VS Code language server"
  juliaup add release || echo "Could not add the release channel. VS Code will offer to install it."
fi

# In this folder, make the `julia` command start this version.
juliaup override unset >/dev/null 2>&1 || true
juliaup override set "$JULIA_VERSION"

# Make the Julia package manager use the `git` command of the computer for git
# URLs. The git library in Julia does not read the git configuration of the
# computer. As a result, Julia can show a prompt for credentials. The export
# applies to this script. The line in startup.jl applies to all subsequent
# Julia sessions on this computer (terminal, scripts, and VS Code).
if command -v git >/dev/null 2>&1; then
  export JULIA_PKG_USE_CLI_GIT=true
  startup_file="$HOME/.julia/config/startup.jl"
  if ! grep -qs JULIA_PKG_USE_CLI_GIT "$startup_file"; then
    mkdir -p "$(dirname "$startup_file")"
    printf '\n%s\n' 'haskey(ENV, "JULIA_PKG_USE_CLI_GIT") || (ENV["JULIA_PKG_USE_CLI_GIT"] = "true")  # The setup script added this line. Pkg uses the git command of the computer.' \
      >> "$startup_file"
  fi
fi

# 3. VS Code extension ----------------------------------------------------------
step "Julia extension for VS Code"
if command -v code >/dev/null 2>&1; then
  code --install-extension julialang.language-julia \
    || echo "Could not install it from here. VS Code will offer it when you open this folder."
else
  echo "The 'code' command is not available in this terminal, so this was skipped."
  echo "VS Code will offer the extension when you open this folder (see .vscode/extensions.json)."
fi

# 4. Project packages -----------------------------------------------------------
# setup.jl contains the package list and the package steps. Windows uses the
# same file.
julia "+$JULIA_VERSION" setup.jl

# Summary -----------------------------------------------------------------------
step "Done"
echo "Start Julia with this project's packages:   julia --project=."
if [ "$detached" = yes ]; then
  echo "This folder is no longer a git repository. To publish it as your own project,"
  echo "create an empty repository and run:"
  echo "    git init -b main"
  echo "    git add -A && git commit -m \"Set up project\""
  echo "    git remote add origin <your-repository-url>"
  echo "    git push -u origin HEAD"
fi
echo
echo "IMPORTANT: Open a new terminal before you use 'julia'. If VS Code is open,"
echo "close it and open it again (or run 'Developer: Reload Window')."
if [ "$fresh_juliaup" = yes ]; then
  echo "juliaup was just installed. In this terminal, you can also run:"
  echo "    export PATH=\"\$HOME/.juliaup/bin:\$PATH\""
fi
