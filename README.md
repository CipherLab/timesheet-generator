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
