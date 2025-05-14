import * as vscode from "vscode";
import { generateTimesheet } from "./timesheet";

export function activate(context: vscode.ExtensionContext) {
  console.log("Timesheet generator activated!");

  // Register the command to generate timesheet (normal)
  let disposable = vscode.commands.registerCommand(
    "extension.generateTimesheet",
    async () => {
      await runTimesheetCommand(false, context);
    }
  );
  context.subscriptions.push(disposable);

  // Register the command to generate timesheet (force fetch)
  let forceDisposable = vscode.commands.registerCommand(
    "extension.generateTimesheetForceFetch",
    async () => {
      await runTimesheetCommand(true, context);
    }
  );
  context.subscriptions.push(forceDisposable);
}

async function runTimesheetCommand(forceFetch: boolean, context: vscode.ExtensionContext) {
  try {
    // Get workspace folder (repository path)
    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders) {
      throw new Error("No workspace folder open");
    }
    const repoPath = workspaceFolders[0].uri.fsPath;

    // Show date picker quick input
    const dayOffset = await vscode.window.showInputBox({
      prompt: "Enter date offset (0 for today, -1 for yesterday, etc.)",
      placeHolder: "0",
      validateInput: (input) => {
        return /^-?\d+$/.test(input)
          ? null
          : "Please enter a valid integer";
      },
    });

    if (dayOffset === undefined) {
      return; // User cancelled
    }

    // Show status bar message
    const statusMessage = vscode.window.setStatusBarMessage(
      forceFetch ? "Generating timesheet (force fetch)..." : "Generating timesheet..."
    );

    try {
      // Call the timesheet generation function
      const result = await generateTimesheet(
        repoPath,
        parseInt(dayOffset),
        context.extensionPath,
        forceFetch
      );

      // Create and show output
      const outputPanel = vscode.window.createOutputChannel("Timesheet");
      outputPanel.clear();
      outputPanel.appendLine(result);
      outputPanel.show();

      // Also copy to clipboard
      await vscode.env.clipboard.writeText(result);

      vscode.window.showInformationMessage(
        "Timesheet generated and copied to clipboard!"
      );
    } finally {
      statusMessage.dispose();
    }
  } catch (error) {
    vscode.window.showErrorMessage(
      `Error generating timesheet: ${
        error instanceof Error ? error.message : String(error)
      }`
    );
  }
}

export function deactivate() {}
