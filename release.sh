#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# You can change the default commit message prefix if needed
COMMIT_MESSAGE_PREFIX="chore(release):"
# --- End Configuration ---

echo "Starting the release process..."

# 1. Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Error: You have uncommitted changes. Please commit or stash them before running this script."
    exit 1
fi
echo "✔ No uncommitted changes."

# 2. Ask for version bump type
echo ""
echo "Select version bump type (or enter a specific version like 1.2.3):"
echo "  1) patch (e.g., 0.1.0 -> 0.1.1)"
echo "  2) minor (e.g., 0.1.0 -> 0.2.0)"
echo "  3) major (e.g., 0.1.0 -> 1.0.0)"
read -p "Enter choice (1-3 or version string): " VERSION_CHOICE

VERSION_ARG=""
if [[ "$VERSION_CHOICE" == "1" || "$VERSION_CHOICE" == "patch" ]]; then
    VERSION_ARG="patch"
elif [[ "$VERSION_CHOICE" == "2" || "$VERSION_CHOICE" == "minor" ]]; then
    VERSION_ARG="minor"
elif [[ "$VERSION_CHOICE" == "3" || "$VERSION_CHOICE" == "major" ]]; then
    VERSION_ARG="major"
elif [[ "$VERSION_CHOICE" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
    VERSION_ARG="$VERSION_CHOICE"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

echo ""
echo "Updating version to '$VERSION_ARG'..."
# npm version will:
# 1. Update package.json and package-lock.json
# 2. Create a Git commit with the message "vX.Y.Z" by default, or custom with -m
# 3. Create a Git tag vX.Y.Z
npm version "$VERSION_ARG" -m "$COMMIT_MESSAGE_PREFIX publish v%s"
NEW_VERSION=$(node -p "require('./package.json').version")
echo "✔ Version updated to $NEW_VERSION in package.json and committed."

# 3. Install dependencies (good practice, though compile might not strictly need it if deps haven't changed)
echo ""
echo "Installing dependencies..."
npm install
echo "✔ Dependencies installed."

# 4. Compile the project
echo ""
echo "Compiling the project..."
npm run compile
echo "✔ Project compiled."

# 5. Package the extension
echo ""
echo "Packaging the extension..."
vsce package
echo "✔ Extension packaged. You should find a .vsix file in the current directory."

echo ""
echo "----------------------------------------"
echo "Release script finished successfully!"
echo "----------------------------------------"
echo ""
echo "Next steps:"
echo "1. Review the changes and the created .vsix file."
echo "2. Push the commit and tags to your remote repository:"
echo "   git push --follow-tags"
echo "3. If you are ready to publish to the VS Code Marketplace:"
echo "   vsce publish -p YOUR_VS_MARKETPLACE_TOKEN (replace with your PAT)"
echo "   (Or use 'vsce publish' if you have your PAT configured globally)"
echo ""

exit 0
