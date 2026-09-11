#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> MacClip setup"

# 1. Ensure Homebrew is available
if ! command -v brew &>/dev/null; then
    echo "ERROR: Homebrew not found. Install it from https://brew.sh and re-run this script."
    exit 1
fi

# 2. Install xcodegen if missing
if ! command -v xcodegen &>/dev/null; then
    echo "--> Installing xcodegen via Homebrew..."
    brew install xcodegen
fi

echo "--> xcodegen $(xcodegen --version)"

# 3. Generate the Xcode project
echo "--> Generating MacClip.xcodeproj ..."
xcodegen generate --spec project.yml

echo ""
echo "Done!  Open the project with:"
echo "  open MacClip.xcodeproj"
echo ""
echo "First-time checklist:"
echo "  1. In Xcode → Signing & Capabilities, set your Team (for code signing)."
echo "  2. Build and run (⌘R)."
echo "  3. On first paste attempt, macOS will ask for Accessibility access."
echo "     Grant it in System Settings → Privacy & Security → Accessibility."
echo "  4. Press ⌘⌃V anywhere to open the clipboard history popup."
