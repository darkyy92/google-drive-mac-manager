#!/bin/bash

# Google Drive Uninstaller for macOS
# This script completely removes Google Drive from macOS

# Created by Joël Staub, 12.03.2025

# Exit on errors
set -e

# Create log file
LOG_FILE="/tmp/google_drive_uninstall_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

# Function for logging
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Function to safely remove files
safe_remove() {
  if [ -e "$1" ]; then
    rm -rf "$1" && log "Removed: $1" || log "Failed to remove: $1"
  else
    log "Not found: $1"
  fi
}

log "Starting Google Drive uninstallation process..."

# Check if script is running with root privileges
if [ "$EUID" -ne 0 ]; then
  log "Please run this script with sudo privileges"
  exit 1
fi

# Get the currently logged in user (not root)
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(eval echo ~$CURRENT_USER)

log "Detected current user: $CURRENT_USER (home: $USER_HOME)"

# Force kill all "Google Drive" processes
log "Force killing all 'Google Drive' processes..."
pkill -9 -f "Google Drive" 2>/dev/null && log "All 'Google Drive' processes force killed" || log "No 'Google Drive' processes found to force kill"

# Continue even if Google Drive isn't found. Just log it.
if [ ! -d "/Applications/Google Drive.app" ] && ! pgrep -f "Google Drive" > /dev/null; then
  log "Google Drive does not appear to be installed, but continuing cleanup."
fi

# Remove application bundle
log "Removing Google Drive application bundle..."
safe_remove "/Applications/Google Drive.app"

# Remove LaunchAgents
log "Removing LaunchAgents..."
find /Library/LaunchAgents -name "com.google.drivefs.*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Remove user-specific LaunchAgents
find "$USER_HOME/Library/LaunchAgents" -name "com.google.drivefs.*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Remove Application Support files
log "Removing Application Support files..."
safe_remove "/Library/Application Support/Google/DriveFS"

# Process only the current user's directory
log "Processing user directory: $USER_HOME"

# Remove all Google Drive components for current user
safe_remove "$USER_HOME/Library/Application Support/Google/DriveFS"
safe_remove "$USER_HOME/Library/Application Support/com.google.drivefs.finderhelper"
safe_remove "$USER_HOME/Library/Application Support/com.google.drivefs.finderhelper.findersync"
safe_remove "$USER_HOME/Library/Application Support/com.google.drivefs.fsext"
safe_remove "$USER_HOME/Library/Application Support/com.google.drivefs.helper.gpu"
safe_remove "$USER_HOME/Library/Caches/com.google.drivefs"
safe_remove "$USER_HOME/Library/Saved Application State/com.google.drivefs.savedState"
safe_remove "$USER_HOME/Google Drive"

# Find and remove preference files for current user
find "$USER_HOME/Library/Preferences" -name "com.google.drivefs*.plist" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Find and remove group containers for current user
find "$USER_HOME/Library/Group Containers" -name "*group.com.google.drivefs" -type d 2>/dev/null | while read dir; do
  safe_remove "$dir"
done

# Remove receipt files
log "Removing receipt files..."
find /var/db/receipts -name "com.google.drivefs*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Final check
log "Performing final check..."
INCOMPLETE=0

if [ -d "/Applications/Google Drive.app" ]; then
  log "WARNING: Google Drive.app still exists"
  INCOMPLETE=1
fi

if pgrep -f "Google Drive" > /dev/null; then
  log "WARNING: Google Drive processes are still running"
  INCOMPLETE=1
fi

# Output result
if [ $INCOMPLETE -eq 1 ]; then
  log "WARNING: Some Google Drive components could not be removed. Manual intervention may be required."
  echo "Google Drive uninstallation INCOMPLETE. Check log at $LOG_FILE for details."
  exit 1
else
  log "Google Drive has been successfully uninstalled!"
  echo "Google Drive uninstallation SUCCESSFUL! Log saved to $LOG_FILE"
  exit 0
fi
