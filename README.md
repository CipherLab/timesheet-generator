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
- To build and package the extension, you need Node.js and npm installed. You also need `vsce` installed globally (`npm install -g vsce`).

## Building and Installing Locally

If you want to build and install the extension from source:

1. Clone the repository.
2. Navigate to the project directory in your terminal.
3. Install dependencies: `npm install`
4. Compile the project: `npm run compile` (If you encounter a TypeScript error about `suite` or `test`, run `npm install --save-dev @types/mocha` and try compiling again).
5. Package the extension: `vsce package` (This will create a `.vsix` file in the project directory).
6. Open VS Code.
7. Open the Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`).
8. Search for and select "Extensions: Install from VSIX...".
9. Navigate to the project directory and select the generated `.vsix` file (`timesheet-generator-X.Y.Z.vsix`, where X.Y.Z is the version).
10. Reload VS Code if prompted.

## Extension Settings

This extension contributes the following settings:

* `timesheet-generator.defaultAuthor`: Default author name to use if not specified

## Known Issues

- May expose the truth about how little work you actually did
- The formatting is optimized for copy-paste, not for visual appeal

## Release Notes

### 1.0.0

Initial release of Timesheet Generator
