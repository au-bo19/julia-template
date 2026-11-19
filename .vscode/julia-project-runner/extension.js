// Julia Project Runner. The setup script of the Julia project template builds
// and installs this extension. The keys Ctrl+Enter, Shift+Enter, Alt+Enter, and
// Alt+Shift+Enter call the command `juliaProjectRunner.run` with a command of
// the Julia extension as the argument.
//
// The command does these steps:
//   1. It finds the project of the file: the nearest folder above the file that
//      has a Project.toml file.
//   2. If the REPL belongs to a different project, it restarts the REPL in the
//      project of the file, with the Julia version in .julia-version. Thus the
//      variables of one project never carry over into a different project.
//   3. It runs the command of the Julia extension.
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

const JULIA = 'julialang.language-julia';
const isWindows = process.platform === 'win32';

// The REPL terminal and the project that it belongs to.
let known = { terminal: undefined, project: undefined };
// The commands run one after the other, also if you push keys quickly.
let queue = Promise.resolve();

function samePath(a, b) {
  if (!a || !b) return false;
  a = path.resolve(a); b = path.resolve(b);
  return isWindows ? a.toLowerCase() === b.toLowerCase() : a === b;
}

function findProject(file) {
  let dir = path.dirname(file);
  for (;;) {
    if (fs.existsSync(path.join(dir, 'Project.toml')) || fs.existsSync(path.join(dir, 'JuliaProject.toml'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) return undefined;
    dir = parent;
  }
}

function juliaVersion(project) {
  try {
    return fs.readFileSync(path.join(project, '.julia-version'), 'utf8').trim() || undefined;
  } catch {
    return undefined;
  }
}

function replTerminal() {
  return vscode.window.terminals.find(t => t.name.startsWith('Julia REPL'));
}

// Asks the running REPL if its active project is `project`.
async function replIsIn(project) {
  const api = vscode.extensions.getExtension(JULIA).exports;
  const code = `Base.samefile(dirname(something(Base.active_project(), "")), raw"${project}")`;
  const result = await api.executeInREPL(code, {
    filename: 'julia-project-runner', showCodeInREPL: false, showResultInREPL: false, showErrorInREPL: false
  });
  return String(result && result.inline).trim() === 'true';
}

// Makes the next REPL start use the environment and the Julia version of `project`.
async function prepare(project) {
  await vscode.commands.executeCommand('language-julia.changeCurrentEnvironment', project);
  const version = juliaVersion(project);
  const config = vscode.workspace.getConfiguration('julia');
  if (version && vscode.workspace.workspaceFolders && config.get('executablePath') !== `julia +${version}`) {
    await config.update('executablePath', `julia +${version}`, vscode.ConfigurationTarget.Workspace);
  }
}

async function run(juliaCommand) {
  const editor = vscode.window.activeTextEditor;
  const file = editor && editor.document.uri.scheme === 'file' ? editor.document.uri.fsPath : undefined;
  const project = file ? findProject(file) : undefined;

  if (project) {
    let terminal = replTerminal();
    let inProject = false;
    if (terminal) {
      inProject = known.terminal === terminal
        ? samePath(known.project, project)
        : await replIsIn(project);
    }
    if (terminal && !inProject) {
      await prepare(project);
      await vscode.commands.executeCommand('language-julia.restartREPL');
      vscode.window.showInformationMessage(
        `The Julia REPL restarted for the project "${path.basename(project)}". ` +
        'The variables of the previous project are gone.');
    } else if (!terminal) {
      await prepare(project);
    }
  } else if (file) {
    vscode.window.setStatusBarMessage(
      'This file is not in a Julia project. The code runs in the current REPL.', 5000);
  }

  await vscode.commands.executeCommand(juliaCommand);
  if (project) known = { terminal: replTerminal(), project };
}

function activate(context) {
  context.subscriptions.push(vscode.commands.registerCommand('juliaProjectRunner.run', (juliaCommand) => {
    const command = typeof juliaCommand === 'string' ? juliaCommand : 'language-julia.executeCodeBlockOrSelection';
    const next = queue.then(() => run(command));
    queue = next.catch(err => {
      vscode.window.showErrorMessage(`Julia Project Runner: ${err && err.message ? err.message : err}`);
    });
    return next;
  }));
  context.subscriptions.push(vscode.window.onDidCloseTerminal(t => {
    if (t === known.terminal) known = { terminal: undefined, project: undefined };
  }));
  // The keys in keybindings.json apply only when this extension is active.
  // Without the extension, the keys of the Julia extension apply.
  vscode.commands.executeCommand('setContext', 'juliaProjectRunner.active', true);
}

function deactivate() {}

module.exports = { activate, deactivate };
