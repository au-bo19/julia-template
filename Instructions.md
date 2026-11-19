# Julia project setup guide

How to start a Julia project in VS Code, manage its packages, and run code with
<kbd>Ctrl</kbd>+<kbd>Enter</kbd> / <kbd>Shift</kbd>+<kbd>Enter</kbd> in the
project's environment.

## Per project

### 0. Open the folder, not a file

Use **File → Open Folder…** and pick your project folder (for example
`julia-project`). If you use Remote-SSH, open the folder on the remote machine.

Beginners get this step wrong more often than any other. If you open only a
single `.jl` file, the extension has no project folder and uses the global
default environment instead.

### 1. Create the environment and add packages

Start the REPL with <kbd>Alt</kbd>+<kbd>J</kbd> then <kbd>Alt</kbd>+<kbd>O</kbd>,
or run **Julia: Start REPL** from the Command Palette. Press <kbd>]</kbd> to
switch to package mode. The prompt changes to `pkg>`:

```julia-repl
pkg> activate .
pkg> add DataFrames CSV Plots
```

This creates `Project.toml` and `Manifest.toml` in the folder. From then on,
the extension uses this environment every time you open the folder. The status
bar at the bottom shows `Julia env: julia-project`.

Other package commands, all typed at the `pkg>` prompt:

| Task                                                             | Command         |
| ---------------------------------------------------------------- | --------------- |
| Remove a package                                                 | `rm Plots`      |
| Update everything                                                | `up`            |
| Update one package                                               | `up DataFrames` |
| See what's installed                                             | `st`            |
| Install everything in `Project.toml` (for example after cloning) | `instantiate`   |

To go back to normal Julia, press <kbd>Backspace</kbd> on an empty `pkg>`
prompt.

There's also a shortcut. If you type `using SomePackage` in the REPL and the
package isn't installed, Julia offers to install it into the active
environment. Answer `y`.

### 2. Create your script

Put the script wherever you like: at the top level, or in `src/script.jl`. The
environment comes from the open folder, not from where the file is, so
subfolders work the same way.

`src/` has a special meaning if you ever turn the project into a package:
`src/ProjectName.jl` is then the package's main file. For plain scripts, many
people use a `scripts/` folder instead, but `src/` works fine.

### 3. Run code with the keyboard

With the folder open and `Project.toml` in place:

| Keys                                | What it runs                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------- |
| <kbd>Ctrl</kbd>+<kbd>Enter</kbd>    | The selection, or the code block at the cursor (a whole `function`, `for` loop, and so on)         |
| <kbd>Shift</kbd>+<kbd>Enter</kbd>   | The same, then moves the cursor to the next block                                                  |
| <kbd>Alt</kbd>+<kbd>Enter</kbd>     | The current cell. Cells are blocks separated by lines that start with `##`                         |

If no REPL is running yet, these keys start one that already uses the project's
environment. You don't need to activate anything by hand.

If the status bar ever shows the wrong environment (for example
`Julia env: v1.13`), click it, choose your project folder, and restart the
REPL. VS Code remembers this choice for the folder.

## Running outside VS Code

From a terminal inside the project folder:

```bash
julia --project=@. src/script.jl
```

`@.` tells Julia to search upward from the current folder for the nearest
`Project.toml`.

## Sharing with others

Commit both `Project.toml` and `Manifest.toml` to version control. Anyone else
then only needs to:

1. Open the folder in VS Code.
2. Start the REPL and run `] instantiate`.
3. Use <kbd>Ctrl</kbd>/<kbd>Shift</kbd>+<kbd>Enter</kbd> as usual.
