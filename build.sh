#!/bin/bash

APP_NAME="ScreenSplit"
APP_BUNDLE="${APP_NAME}.app"
APP_MACOS="${APP_BUNDLE}/Contents/MacOS"

echo "Creating app bundle structure..."
mkdir -p "${APP_MACOS}"

echo "Copying Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/"

echo "Compiling Swift files..."
swiftc Sources/*.swift -o "${APP_MACOS}/${APP_NAME}" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework ApplicationServices \
    -framework Carbon

if [ $? -eq 0 ]; then
    # Codesigning
    # To prevent losing Accessibility permissions on every build, we look for a stable local certificate.
    echo "Codesigning app..."
    CERT_NAME="ScreenSplitLocal"

    # Check if the stable local certificate exists
    if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
        echo "Stable local certificate '$CERT_NAME' found. Signing with it to preserve permissions..."
        codesign --force --deep --sign "$CERT_NAME" --options runtime "${APP_BUNDLE}"
    else
        echo "No stable certificate found. Falling back to ad-hoc signature (-)."
        echo "Note: Ad-hoc signatures change on every build, which resets macOS Accessibility permissions."
        codesign --force --deep --sign - "${APP_BUNDLE}"
    fi
    echo "Build successful! Application is ready at ${APP_BUNDLE}"
else
    echo "Build failed."
    exit 1
fi
