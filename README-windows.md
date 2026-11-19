# Julia project template: Windows

Use this template to start a Julia project for data analysis. The `setup.ps1`
script installs Julia, the VS Code extension, and a set of packages.

For Linux and macOS, see [README-linux-macos.md](README-linux-macos.md).

## Before you start

Make sure that these tools are on your computer:

- `git`
- `winget`. Windows 10 and Windows 11 usually include this tool.

Administrator rights are not necessary.

## Quick start

Run these commands in PowerShell:

```powershell
git clone <template-repository-url> my-project
cd my-project
powershell -ExecutionPolicy Bypass -File setup.ps1
```

The setup script does these four tasks:

1. It disconnects the clone from the template repository. It deletes the `.git`
   folder. Thus the folder is no longer a git repository, you cannot
   accidentally push to the template, and your project starts without the
   history of the template.
2. It installs the Julia version that is in `.julia-version`. If juliaup is
   missing, the script installs Julia and juliaup from the Microsoft Store with
   `winget`. The script also installs the `release` channel of juliaup, which
   the language server of VS Code uses. It sets the Julia package manager to
   use the `git` command of the computer. This is necessary for some packages
   that you add from a git URL.
3. It installs the Julia extension for VS Code.
4. It runs `setup.jl`. This file makes the project environment and precompiles
   the packages. The packages are Arrow, BenchmarkTools, Chain, DataFrames,
   Dates, and DBInterface. `setup.jl` also prepares VS Code (see
   [How to run code in VS Code](#how-to-run-code-in-vs-code)):
   - It writes the Julia version of `.julia-version` into
     `.vscode/settings.json`.
   - It installs Revise in the default environment of that Julia version.
     The Julia REPL of VS Code loads Revise.
   - It makes the `julia>` prompt show the active environment, for example
     `(my-project) julia>`.

**After the script, open a new terminal.** If VS Code is open, close it and
open it again (or run **Developer: Reload Window**). Then VS Code and the
terminal use the new settings.

If the script installed Julia and a new terminal cannot find `julia`, sign out
of Windows and sign in again.

## How to make your own repository

After the setup, the folder is not a git repository. Make an empty repository on
your git server. Then run these commands:

```powershell
git init -b main
git add -A
git commit -m "Set up project"
git remote add origin <your-repository-url>
git push -u origin main
```

Commit `Project.toml` and `Manifest.toml`. These two files record the packages
and the versions that the project uses.

## How to continue the project on a new computer

The setup scripts, `setup.jl`, and `.julia-version` are part of your project.
Thus the procedure on a new computer is the same, but with your repository:

```powershell
git clone <your-repository-url>
cd <your-project>
powershell -ExecutionPolicy Bypass -File setup.ps1
```

On a new computer, the script does these steps:

- It installs the Julia version that is in `.julia-version`.
- It installs the Julia extension for VS Code.
- It installs the same package versions that `Project.toml` and `Manifest.toml`
  record.
- It does not change git. You can pull and push immediately.

A different person who starts to use the project does the same procedure. The
operating system of that person can be different from your operating system.
On Linux and macOS, that person uses `setup.sh` (see
[README-linux-macos.md](README-linux-macos.md)).

A new computer gets only the packages that the project records. If you added
packages without `--project=.`, add them to the project. Then commit
`Project.toml` and `Manifest.toml`.

## How to start Julia in the project

Always start Julia with `--project=.` from the project folder:

```powershell
julia --project=.                 # interactive session
julia --project=. my_script.jl    # run a script
```

In the terminals of VS Code, `julia` without `--project=.` also uses the
project. `.vscode/settings.json` sets `JULIA_PROJECT=@.` for these terminals.

The `julia>` prompt shows the active environment, the same as the `pkg>`
prompt:

| Prompt | Environment |
| --- | --- |
| `(my-project) julia>` | The environment of the project. The packages of the project are available. |
| `(@v1.13) julia>` | The default environment of the computer. The packages of the project are not available. |

If you do not use `--project=.`, Julia uses the default environment on the
computer. This environment is in `%USERPROFILE%\.julia\environments`. The
project does not record the packages that you add there. Thus these packages are
not available on a new computer or to other persons.

## How to run code in VS Code

Open the project folder in VS Code (**File > Open Folder**). Open the folder of
the project, not a folder above it. Then open a `.jl` file and use these keys:

| Key | Action |
| --- | --- |
| Shift+Enter | Run the current line or block, and go to the next block |
| Ctrl+Enter | Run the current line or block |
| Alt+Enter | Run the current cell (cells are separated by `##` lines) |

To run part of a line or a group of lines, select the code first. To run the
full file, use the command **Julia: Execute File in REPL**.

The first key starts the Julia REPL of VS Code. This REPL always uses the
project environment and the Julia version of the project.
`.vscode/settings.json` sets these values. Thus the packages of the project
are available immediately. To see the environment, look at the status bar
(`Julia env: my-project`) or at the REPL prompt (`(my-project) julia>`).

After you run code, the **Workspace** pane of the Julia extension shows the
variables. The plots open in the plot pane.

If the REPL shows `(@v1.13) julia>` or says that a package of the project is
not installed, do these steps:

1. Make sure that you opened the project folder, not a folder above it.
2. Run **Developer: Reload Window**. VS Code reads `.vscode/settings.json` again.
3. If the problem continues, run `setup.ps1` again.

## Package management

Start `julia --project=.`. Then type `]` to go into package mode. The prompt
changes to `(my-project) pkg>`.

If the prompt shows `(@v1.12) pkg>`, you are in the environment of the full
computer. Stop Julia and start it again with `--project=.`.

To go out of package mode, push the Backspace key.

| Task | Command in package mode |
| --- | --- |
| Show the installed packages | `status` |
| Add a package | `add CSV` |
| Add a specified version | `add CSV@0.10` |
| Remove a package | `rm CSV` |
| Show the packages that have updates | `status --outdated` |
| Update one package | `up DataFrames` |
| Update all packages | `up` |

Use package mode for these tasks. Do not use `julia -e "..."` commands from
PowerShell: PowerShell can remove the quotation marks in the Julia code, and
then the command fails.

Each of these commands changes `Project.toml`, `Manifest.toml`, or the two
files. Commit the changes. Then other computers get the same packages.

```powershell
git add Project.toml Manifest.toml
git commit -m "Add CSV"
```

To cancel a package change that you did not commit, run this command:

```powershell
git checkout Project.toml Manifest.toml
```

Then run `setup.ps1` again.

After you pull package changes from a different person, run `setup.ps1` again.
As an alternative, use `instantiate` in package mode.

`Dates` and the other standard libraries are part of Julia. They do not have
their own versions. Thus you cannot update them separately.

### Packages that are not in the registry

Some packages are only in a git repository (for example, on GitHub or GitLab).
Add these packages with their URLs. This is possible only if the `git` command
of the computer can clone the repository.

The commands in this table use the `Example` package as an example. Replace the
URL with the URL of your package.

| Task | Command in package mode |
| --- | --- |
| Add a package from a git URL | `add https://github.com/JuliaLang/Example.jl.git` |
| Add a specified branch, tag, or commit | `add https://github.com/JuliaLang/Example.jl.git#master` |
| Update to the latest commit | `up Example` |
| Remove the package | `rm Example` |

Then use the package the same as all other packages. Write `using Example` in
your code. Commit `Project.toml` and `Manifest.toml`. The manifest records the
URL and the commit. Thus the setup script on a new computer downloads the same
code again.

If Julia shows a prompt for a user name and password, Julia does not use the
`git` command of the computer. The setup script sets this configuration for the
full computer. It adds a line to `%USERPROFILE%\.julia\config\startup.jl`. Do
these steps:

1. Run `setup.ps1` if you did not run it on this computer.
2. Stop Julia and start it again.
3. Make sure that `ENV["JULIA_PKG_USE_CLI_GIT"]` shows `"true"`.

Do not clone a package into your home folder and then install it with
`Pkg.develop(path=...)`. This method records a folder that is only on this
computer. Thus the project does not operate on a different computer. Use
`develop` only when you change the code of that package.

To put a package from a git URL into all new projects, add the URL to
`DEFAULT_PACKAGES` in `setup.jl`.

## How to change the Julia version

Change the value in `.julia-version`. Then run `setup.ps1`. You can use all
values that juliaup can use:

- a series, for example `1.12` (the latest 1.12.x version)
- a full version, for example `1.12.6`
- `lts`

After you change to a different series (for example, from 1.12 to 1.13), run
`up` in package mode. This command makes `Manifest.toml` again for the new
version. Then commit the result.

The setup script also writes the new version into `.vscode/settings.json`.
Commit `.julia-version` and `.vscode/settings.json` together.

In the project folder, the `julia` command starts the version that is in
`.julia-version`. The REPL of VS Code also uses this version. In other folders,
the `julia` command starts the default version of juliaup. To see the default
version, run `juliaup status`.

The language server of VS Code always uses the `release` channel of juliaup.
This does not change the version of your code.

## What the setup script changes outside the project

The setup script changes these files and folders in your home folder. These
changes apply to all Julia sessions on the computer:

- `.julia/config/startup.jl`: two lines. One line makes the package manager use
  the `git` command of the computer. The other line loads
  `.julia/config/project_prompt.jl`, which shows the active environment in the
  `julia>` prompt. To remove a feature, delete its line.
- The default environment of the Julia version (for example `@v1.13`): the
  script adds Revise.
- juliaup: the Julia version of the project and the `release` channel.

## For template maintainers

The template contains these setup files:

| File | Function |
| --- | --- |
| `setup.sh` | The setup script for Linux and macOS |
| `setup.ps1` | The setup script for Windows |
| `setup.jl` | The package steps. The two setup scripts run this file. |
| `.julia-version` | The Julia version |
| `.vscode/settings.json` | The VS Code settings: the project environment and the Julia version for the REPL. `setup.jl` changes `julia.executablePath`. |

Three parameters control the contents of new projects:

- `.julia-version`: the Julia version. Do not change `julia.executablePath` in
  `.vscode/settings.json` manually. `setup.jl` copies the value from
  `.julia-version`.
- `DEFAULT_PACKAGES` at the top of `setup.jl`: the initial packages. Each entry
  is a registry name or the git URL of a package that is not in the registry.
- `$TemplateRepoName` at the top of `setup.ps1` and `TEMPLATE_REPO_NAME` at the
  top of `setup.sh`: the name of this repository. Make sure that the two values
  are the same and are correct.

The setup script deletes the `.git` folder only if all these conditions are
true:

- The `origin` URL has the name of the template repository at its end.
- The project does not have a `Project.toml` file. This is the condition of a
  new clone of the template.
- The clone has no commits that are not on `origin`.
- The git setting `template.maintainer` is not `true`.

Your own clone of the template looks the same as a new clone. Thus, before you
run `setup.ps1` in it, run this command once in that clone. If you do not, the
script deletes the `.git` folder of your clone:

```powershell
git config template.maintainer true
```

This setting is only in the clone. It is not part of the template.

The template does not contain `Project.toml` or `Manifest.toml`. The first run
of the setup script in a project makes these files. Thus each new project starts
with the current package versions. Do not commit these files to the template.
