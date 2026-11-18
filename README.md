# Julia project template

Use this template to start a Julia project for data analysis. One script
installs Julia, the VS Code extension, and a set of packages. The template has a
script for Linux and macOS and a script for Windows.

## Before you start

Make sure that these tools are on your computer:

- All operating systems: `git`.
- Linux and macOS: `curl`. `sudo` is not necessary.
- Windows: `winget`. Windows 10 and Windows 11 usually include this tool.

## Quick start

Linux and macOS:

```bash
git clone <template-repository-url> my-project
cd my-project
./setup.sh
```

Windows (PowerShell):

```powershell
git clone <template-repository-url> my-project
cd my-project
powershell -ExecutionPolicy Bypass -File setup.ps1
```

The setup script does these four tasks:

1. It disconnects the clone from the template repository and removes the commit
   history of the template. Thus you cannot accidentally push to the template,
   and your project starts with no commits.
2. It installs the Julia version that is in `.julia-version`. If juliaup is
   missing, the script installs juliaup for your user account. The script also
   sets the Julia package manager to use the `git` command of the computer. This
   is necessary for some packages that you add from a git URL.
3. It installs the Julia extension for VS Code.
4. It runs `setup.jl`. This file makes the project environment and precompiles
   the packages. The packages are Arrow, BenchmarkTools, Chain, DataFrames, Dates, and DBInterface.

If the script installed juliaup, open a new terminal. Then the `julia` command
is available.

## How to make your own repository

After the setup, the folder is a git repository without a remote and without
commits. The files of the template are ready for the first commit. Make an empty
repository on your git server. Then run these commands:

```bash
git add -A
git commit -m "Set up project"
git remote add origin <your-repository-url>
git push -u origin HEAD
```

Commit `Project.toml` and `Manifest.toml`. These two files record the packages
and the versions that the project uses.

## How to continue the project on a new computer

The setup scripts, `setup.jl`, and `.julia-version` are part of your project.
Thus the procedure on a new computer is the same, but with your repository:

```bash
git clone <your-repository-url>
cd <your-project>
```

Then run the setup script. On a new computer, the script does these steps:

- It installs the Julia version that is in `.julia-version`.
- It installs the Julia extension for VS Code.
- It installs the same package versions that `Project.toml` and `Manifest.toml`
  record.
- It does not change `origin`. You can pull and push immediately.

A different person who starts to use the project does the same procedure. The
operating system of that person can be different from your operating system.

A new computer gets only the packages that the project records. 
If you added packages without --project=., add them to the project. 
Then commit Project.toml and Manifest.toml

## How to start Julia in the project

Always start Julia with `--project=.` from the project folder:

```bash
julia --project=.                 # interactive session
julia --project=. my_script.jl    # run a script
```

In VS Code, open the project folder. The Julia extension finds the project
automatically. The status bar shows `Julia env: my-project`.

If you do not use `--project=.`, Julia uses the default environment on the
computer. This environment is in the `.julia/environments` folder of your home
folder. The project does not record the packages that you add there. Thus these
packages are not available on a new computer or to other persons.

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

You can also do these tasks from a terminal:

```bash
julia --project=. -e 'using Pkg; Pkg.add("CSV")'
julia --project=. -e 'using Pkg; Pkg.rm("CSV")'
julia --project=. -e 'using Pkg; Pkg.update()'
```

Note: These three commands are for Linux and macOS. In Windows PowerShell, the
quotation marks can cause errors. On Windows, use package mode.

Each of these commands changes `Project.toml`, `Manifest.toml`, or the two
files. Commit the changes. Then other computers get the same packages.

```bash
git add Project.toml Manifest.toml
git commit -m "Add CSV"
```

To cancel a package change that you did not commit, run this command:

```bash
git checkout Project.toml Manifest.toml
```

Then run the setup script again.

After you pull package changes from a different person, run the setup script
again. As an alternative, use `instantiate` in package mode.

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
full computer. It adds a line to the `.julia/config/startup.jl` file in your
home folder. Do these steps:

1. Run the setup script if you did not run it on this computer.
2. Stop Julia and start it again.
3. Make sure that `ENV["JULIA_PKG_USE_CLI_GIT"]` shows `"true"`.

Do not clone a package into your home folder and then install it with
`Pkg.develop(path=...)`. This method records a folder that is only on this
computer. Thus the project does not operate on a different computer. Use
`develop` only when you change the code of that package.

To put a package from a git URL into all new projects, add the URL to
`DEFAULT_PACKAGES` in `setup.jl`.

## How to change the Julia version

Change the value in `.julia-version`. Then run the setup script. You can use all
values that juliaup can use:

- a series, for example `1.12` (the latest 1.12.x version)
- a full version, for example `1.12.6`
- `lts`

After you change to a different series (for example, from 1.12 to 1.13), run
`up` in package mode. This command makes `Manifest.toml` again for the new
version. Then commit the result.

In the project folder, the `julia` command starts the version that is in
`.julia-version`. In other folders, it starts the default version of juliaup. To
see the default version, run `juliaup status`.

If VS Code starts an incorrect version, run `juliaup default <version>`. This
command sets the default version.

## For template maintainers

The template contains these setup files:

| File | Function |
| --- | --- |
| `setup.sh` | The setup script for Linux and macOS |
| `setup.ps1` | The setup script for Windows |
| `setup.jl` | The package steps. The two setup scripts run this file. |
| `.julia-version` | The Julia version |

Three parameters control the contents of new projects:

- `.julia-version`: the Julia version.
- `DEFAULT_PACKAGES` at the top of `setup.jl`: the initial packages. Each entry
  is a registry name or the git URL of a package that is not in the registry.
- `TEMPLATE_REPO_NAME` at the top of `setup.sh` and `$TemplateRepoName` at the
  top of `setup.ps1`: the name of this repository. Make sure that the two values
  are the same and are correct.

The setup script removes `origin`, the branches, and the tags only if all these
conditions are true:

- The `origin` URL has the name of the template repository at its end.
- The project does not have a `Project.toml` file. This is the condition of a
  new clone of the template.
- The clone has no commits that are not on `origin`.
- The git setting `template.maintainer` is not `true`.

Your own clone of the template looks the same as a new clone. Thus, before you
run a setup script in it, run this command once in that clone:

```bash
git config template.maintainer true
```

This setting is only in the clone. It is not part of the template.

The template does not contain `Project.toml` or `Manifest.toml`. The first run
of the setup script in a project makes these files. Thus each new project starts
with the current package versions. Do not commit these files to the template.
