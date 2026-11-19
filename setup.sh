#!/usr/bin/env bash
# Install Julia and the Julia VS Code extension on a Linux machine.
# No sudo is needed: everything goes into your home directory.
#
# Usage:
#   ./setup.sh            # installs Julia $JULIA_VERSION (set below)
#   ./setup.sh 1.11       # installs Julia 1.11 instead (any juliaup channel works)
#
# What it does:
#   1. Installs juliaup into ~/.juliaup (if missing) and adds it to PATH in your
#      shell startup files. juliaup then installs Julia into ~/.julia/juliaup.
#   2. Installs the requested Julia version and makes it the default. The
#      `release` channel is always installed too, because the language server
#      of the VS Code extension uses it.
#   3. Installs the Julia VS Code extension (julialang.language-julia) with the
#      `code` command, or with the VS Code Remote-SSH server on this machine.
#
# You can run the script again at any time.
set -euo pipefail

# The Julia version to install. A command-line argument overrides it.
JULIA_VERSION="1.13.4"

CHANNEL="${1:-$JULIA_VERSION}"
EXTENSION="julialang.language-julia"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || fail "this script is for Linux (found $(uname -s))"

# 1. juliaup ----------------------------------------------------------------------
export PATH="$HOME/.juliaup/bin:$PATH"
fresh_juliaup=no
if command -v juliaup >/dev/null 2>&1; then
  step "juliaup is already installed ($(command -v juliaup))"
else
  step "Installing juliaup and Julia ($CHANNEL) into your home directory"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://install.julialang.org | sh -s -- --yes --default-channel "$CHANNEL"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://install.julialang.org | sh -s -- --yes --default-channel "$CHANNEL"
  else
    fail "curl or wget is required to download juliaup"
  fi
  command -v juliaup >/dev/null 2>&1 || fail "juliaup was not installed in ~/.juliaup/bin"
  fresh_juliaup=yes
fi

# 2. Julia ------------------------------------------------------------------------
has_channel() { juliaup status 2>/dev/null | grep -qw -- "$1"; }

if ! has_channel "$CHANNEL"; then
  step "Installing Julia channel $CHANNEL"
  juliaup add "$CHANNEL" || fail "could not install Julia channel '$CHANNEL'"
fi
juliaup default "$CHANNEL"

if ! has_channel release; then
  step "Installing the release channel (used by the VS Code language server)"
  juliaup add release || echo "Could not add the release channel. VS Code will offer to install it."
fi

julia --version || fail "Julia does not start"

# 3. VS Code extension ------------------------------------------------------------
# Prefer the `code` command (a VS Code terminal, or VS Code installed locally).
# Otherwise use the newest VS Code Remote-SSH server in ~/.vscode-server, which
# exists once you have connected to this machine with VS Code at least once.
find_vscode_cli() {
  if command -v code >/dev/null 2>&1; then
    command -v code
    return
  fi
  local servers
  servers=$(ls -1t \
    "$HOME"/.vscode-server/cli/servers/*/server/bin/code-server \
    "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null || true)
  printf '%s\n' "$servers" | head -n 1
}

step "Installing the Julia VS Code extension"
vscode_cli="$(find_vscode_cli)"
if [ -n "$vscode_cli" ]; then
  "$vscode_cli" --install-extension "$EXTENSION" --force \
    || echo "Could not install the extension. Install '$EXTENSION' from the Extensions view of VS Code."
else
  echo "VS Code was not found on this machine, so this step was skipped."
  echo "Connect to this machine with VS Code (Remote-SSH) and run this script again"
  echo "in a VS Code terminal, or install '$EXTENSION' from the Extensions view."
fi

# Summary -------------------------------------------------------------------------
step "Done"
juliaup status
echo
if [ "$fresh_juliaup" = yes ]; then
  echo "juliaup added itself to PATH in your shell startup files. Open a new terminal,"
  echo "or run this in the current one:"
  echo "    export PATH=\"\$HOME/.juliaup/bin:\$PATH\""
fi
echo "If VS Code is connected to this machine, reload the window"
echo "(Developer: Reload Window) so the extension finds Julia."

# Julia is installed in the home directory, so the folder with this script is
# no longer needed. There is no folder when the script comes from a pipe.
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  echo
  echo "Julia does not need this folder. You can delete it now:"
  echo "    rm -rf \"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)\""
fi
