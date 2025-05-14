// Extension Project Structure
/*
timesheet-extension/
+-- .vscode/
¦   +-- launch.json
+-- src/
¦   +-- extension.ts
¦   +-- timesheet.ts
+-- package.json
+-- tsconfig.json
+-- README.md
*/

// extension.ts - Main extension entry point
import * as vscode from 'vscode';
import { generateTimesheet } from './timesheet';

export function activate(context: vscode.ExtensionContext) {
    console.log('Timesheet generator activated!');

    // Register the command to generate timesheet
    let disposable = vscode.commands.registerCommand('extension.generateTimesheet', async () => {
        try {
            // Get workspace folder (repository path)
            const workspaceFolders = vscode.workspace.workspaceFolders;
            if (!workspaceFolders) {
                throw new Error('No workspace folder open');
            }
            const repoPath = workspaceFolders[0].uri.fsPath;

            // Show date picker quick input
            const dayOffset = await vscode.window.showInputBox({
                prompt: 'Enter date offset (0 for today, -1 for yesterday, etc.)',
                placeHolder: '0',
                validateInput: (input) => {
                    return /^-?\d+$/.test(input) ? null : 'Please enter a valid integer';
                }
            });
            
            if (dayOffset === undefined) {
                return; // User cancelled
            }

            // Show status bar message
            const statusMessage = vscode.window.setStatusBarMessage('Generating timesheet...');
            
            try {
                // Call the timesheet generation function
                const result = await generateTimesheet(repoPath, parseInt(dayOffset));

                // Create and show output
                const outputPanel = vscode.window.createOutputChannel('Timesheet');
                outputPanel.clear();
                outputPanel.appendLine(result);
                outputPanel.show();

                // Also copy to clipboard
                await vscode.env.clipboard.writeText(result);
                
                vscode.window.showInformationMessage('Timesheet generated and copied to clipboard!');
            } finally {
                statusMessage.dispose();
            }
        } catch (error) {
            vscode.window.showErrorMessage(`Error generating timesheet: ${error instanceof Error ? error.message : String(error)}`);
        }
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {}

// timesheet.ts - Timesheet generation logic
import * as cp from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';

export async function generateTimesheet(repoPath: string, dayOffset: number): Promise<string> {
    // Create a temporary script file
    const scriptContent = getScriptContent();
    const tempScriptPath = path.join(os.tmpdir(), `git_commits_${Date.now()}.sh`);
    
    try {
        // Write script to temp file
        fs.writeFileSync(tempScriptPath, scriptContent, { mode: 0o755 });
        
        // Execute the script
        const result = cp.execSync(`"${tempScriptPath}" -r "${repoPath}" -d ${dayOffset}`, {
            encoding: 'utf8',
            maxBuffer: 1024 * 1024 * 5 // 5MB buffer
        });
        
        return result;
    } finally {
        // Clean up temp file
        try {
            fs.unlinkSync(tempScriptPath);
        } catch (error) {
            console.error('Failed to delete temporary script file:', error);
        }
    }
}

function getScriptContent(): string {
    // This is where we'll embed your entire shell script
    // For brevity I'm just including the beginning, but you would paste your entire script here
    return `#!/bin/bash

# Embedded git_commits.sh script
# Original script by Shell Script Archaeologist Extraordinaire

# Default repository path (adjust if needed)
DEFAULT_REPO_PATH="/home/mnewport/repos/wyffels/Sales-App"
# On WSL, you might need the Linux path directly like above,
# or translate the Windows path if running Bash outside WSL directly:
# DEFAULT_REPO_PATH="/mnt/c/path/to/your/repo"

# --- Argument Parsing ---
FORCE_FETCH=false
SHOW_HELP=false
day_offset_param=""
author_index_param=""

# Process command line options
while getopts "fhr:d:a:" opt; do
  case ${opt} in
    f ) # Force fetch
      FORCE_FETCH=true
      ;;
    r ) # Custom repo path
      custom_repo_path=$OPTARG
      ;;
    h ) # Help
      SHOW_HELP=true
      ;;
    d ) # Day offset
      day_offset_param=$OPTARG
      ;;
    a ) # Author index
      author_index_param=$OPTARG
      ;;
    \\? )
      echo "Usage: $0 [-f] [-r repo_path] [-d day_offset] [-a author_index] [-h]"
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# ... PASTE THE REST OF YOUR SCRIPT HERE ...
# For demo purposes we'll truncate it, but in real implementation
# you would include the entire script
`;
}

// package.json - Extension manifest
/*
{
  "name": "timesheet-generator",
  "displayName": "Timesheet Generator",
  "description": "Generate timesheet entries from Git commits",
  "version": "0.1.0",
  "engines": {
    "vscode": "^1.60.0"
  },
  "categories": [
    "Other"
  ],
  "activationEvents": [],
  "main": "./dist/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "extension.generateTimesheet",
        "title": "Generate Timesheet from Commits"
      }
    ]
  },
  "scripts": {
    "vscode:prepublish": "npm run package",
    "compile": "webpack",
    "watch": "webpack --watch",
    "package": "webpack --mode production --devtool hidden-source-map",
    "lint": "eslint src --ext ts"
  },
  "devDependencies": {
    "@types/vscode": "^1.60.0",
    "@types/node": "^16.11.7",
    "@typescript-eslint/eslint-plugin": "^5.30.0",
    "@typescript-eslint/parser": "^5.30.0",
    "eslint": "^8.18.0",
    "typescript": "^4.7.4",
    "webpack": "^5.73.0",
    "webpack-cli": "^4.10.0",
    "ts-loader": "^9.3.1"
  }
}
*/

// README.md - Documentation
/*
# Timesheet Generator

A VS Code extension that generates timesheet entries from your Git commits.

## Features

- Extracts your Git commits for a specific day
- Formats them in a timesheet-friendly format
- Copies the result to your clipboard
- Saves you from the torment of remembering what you did yesterday

## Usage

1. Open your Git repository in VS Code
2. Press Ctrl+Shift+P (or Cmd+Shift+P on macOS) to open the Command Palette
3. Type "Generate Timesheet" and select the command
4. Enter the date offset (0 for today, -1 for yesterday, etc.)
5. Wait for the magic to happen
6. Paste the generated timesheet into your time tracking system

## Requirements

- Git must be installed and available in your PATH
- Your repository should have some commits (shocking, I know)

## Extension Settings

This extension contributes the following settings:

* `timesheet-generator.defaultAuthor`: Default author name to use if not specified

## Known Issues

- May expose the truth about how little work you actually did
- The formatting is optimized for copy-paste, not for visual appeal

## Release Notes

### 1.0.0

Initial release of Timesheet Generator
*/