#!/bin/bash
set -e

# Forest installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ricwo/forest/main/install.sh | bash

REPO="ricwo/forest"
APP_NAME="forest.app"
INSTALL_DIR="/Applications"

echo "==> Installing forest..."
echo "    Fetching latest release info..."

# Get latest release URL
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep "browser_download_url.*forest.dmg" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find latest release"
    exit 1
fi

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download DMG
echo "==> Downloading $DOWNLOAD_URL"
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/forest.dmg"

# Mount DMG
echo "==> Mounting disk image..."
MOUNT_DIR=$(hdiutil attach "$TMP_DIR/forest.dmg" -nobrowse | grep "/Volumes" | sed 's/.*\(\/Volumes\/.*\)/\1/')

# Remove old version if exists
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    echo "==> Removing old version..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Copy app
echo "==> Installing to $INSTALL_DIR..."
cp -R "$MOUNT_DIR/$APP_NAME" "$INSTALL_DIR/"

# Unmount DMG
echo "==> Cleaning up..."
hdiutil detach "$MOUNT_DIR" -quiet

# Remove quarantine attribute (bypass Gatekeeper for unsigned app)
xattr -cr "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

echo "==> Done! Run 'open /Applications/forest.app' or find forest in Spotlight."
