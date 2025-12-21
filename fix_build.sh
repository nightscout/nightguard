#!/bin/bash

# Fix for "Multiple commands produce" build error
# This script updates the WatchKit App product name to avoid conflicts

echo "Fixing build configuration..."

# Backup the project file
cp nightguard.xcodeproj/project.pbxproj nightguard.xcodeproj/project.pbxproj.backup

# For the WatchKit App target, change PRODUCT_NAME to use TARGET_NAME
# This prevents both targets from producing the same output
sed -i.bak '/watchos/,/PRODUCT_NAME = nightguard/{
    s/PRODUCT_NAME = nightguard;/PRODUCT_NAME = "$(TARGET_NAME)";/
}' nightguard.xcodeproj/project.pbxproj

# Remove the sed backup file
rm nightguard.xcodeproj/project.pbxproj.bak

echo "Build configuration fixed!"
echo "Now run: xcodebuild -workspace nightguard.xcworkspace -scheme nightguard clean build"
