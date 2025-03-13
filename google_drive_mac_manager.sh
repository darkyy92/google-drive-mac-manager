#!/bin/bash

# Google Drive Manager for macOS
# This script completely removes Google Drive from macOS and optionally reinstalls it
# Created by Joël Staub, 13.03.2025

# Exit on errors
set -e

# Define colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Create log file
LOG_FILE="/tmp/google_drive_uninstall_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

# Function for logging
log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Determine color based on message type
  local color=$RESET
  if [[ "$1" == *"SUCCESS"* || "$1" == *"successfully"* ]]; then
    color=$GREEN
  elif [[ "$1" == *"WARNING"* || "$1" == *"Not found"* ]]; then
    color=$YELLOW
  elif [[ "$1" == *"ERROR"* || "$1" == *"INCOMPLETE"* || "$1" == *"failed"* || "$1" == *"Failed"* ]]; then
    color=$RED
  fi
  
  echo "${color}${timestamp} - $1${RESET}" | tee -a "$LOG_FILE"
}

# Function to safely remove files
safe_remove() {
  if [ -e "$1" ]; then
    rm -rf "$1" && log "Removed: $1" || log "Failed to remove: $1"
  else
    log "Not found: $1"
  fi
}

log "${BOLD}Starting Google Drive uninstallation process...${RESET}"

# Check if script is running with root privileges
if [ "$EUID" -ne 0 ]; then
  log "${RED}ERROR: Please run this script with sudo privileges${RESET}"
  exit 1
fi

# Get the currently logged in user (not root)
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(eval echo ~$CURRENT_USER)

log "Detected current user: ${BLUE}${CURRENT_USER}${RESET} (home: ${BLUE}${USER_HOME}${RESET})"

# Force kill all "Google Drive" processes
log "${BOLD}Force killing all 'Google Drive' processes...${RESET}"
pkill -9 -f "Google Drive" 2>/dev/null && log "${GREEN}All 'Google Drive' processes force killed${RESET}" || log "${YELLOW}No 'Google Drive' processes found to force kill${RESET}"

# Continue even if Google Drive isn't found. Just log it.
if [ ! -d "/Applications/Google Drive.app" ] && ! pgrep -f "Google Drive" > /dev/null; then
  log "${YELLOW}Google Drive does not appear to be installed, but continuing cleanup.${RESET}"
fi

# Remove application bundle
log "${BOLD}Removing Google Drive application bundle...${RESET}"
safe_remove "/Applications/Google Drive.app"

# Remove LaunchAgents
log "${BOLD}Removing LaunchAgents...${RESET}"
find /Library/LaunchAgents -name "com.google.drivefs.*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Remove user-specific LaunchAgents
find "$USER_HOME/Library/LaunchAgents" -name "com.google.drivefs.*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Remove Application Support files
log "${BOLD}Removing Application Support files...${RESET}"
safe_remove "/Library/Application Support/Google/DriveFS"

# Process only the current user's directory
log "${BOLD}Processing user directory: ${USER_HOME}${RESET}"

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
log "${BOLD}Removing receipt files...${RESET}"
find /var/db/receipts -name "com.google.drivefs*" -type f 2>/dev/null | while read file; do
  safe_remove "$file"
done

# Final check
log "${BOLD}Performing final check...${RESET}"
INCOMPLETE=0

if [ -d "/Applications/Google Drive.app" ]; then
  log "${RED}WARNING: Google Drive.app still exists${RESET}"
  INCOMPLETE=1
fi

if pgrep -f "Google Drive" > /dev/null; then
  log "${RED}WARNING: Google Drive processes are still running${RESET}"
  INCOMPLETE=1
fi

# Output result
if [ $INCOMPLETE -eq 1 ]; then
  log "${RED}WARNING: Some Google Drive components could not be removed. Manual intervention may be required.${RESET}"
  echo "${RED}Google Drive uninstallation INCOMPLETE. Check log at $LOG_FILE for details.${RESET}"
  UNINSTALL_STATUS=1
else
  log "${GREEN}Google Drive has been successfully uninstalled!${RESET}"
  echo "${GREEN}Google Drive uninstallation SUCCESSFUL!${RESET} Log saved to $LOG_FILE"
  UNINSTALL_STATUS=0
fi

# Ask if user wants to install Google Drive - fixed to work with curl pipe
echo "${BOLD}Installation Options${RESET}"
read -p "Would you like to install the latest version of Google Drive? (y/n): " INSTALL_CHOICE < /dev/tty

if [[ $INSTALL_CHOICE == "y" || $INSTALL_CHOICE == "Y" ]]; then
  log "${BLUE}User chose to install Google Drive. Starting installation...${RESET}"
  echo "${BLUE}Installing Google Drive...${RESET}"
  
  # Create temporary directory for downloads
  TEMP_DIR="/tmp/googledrive_install"
  mkdir -p "$TEMP_DIR"
  cd "$TEMP_DIR"
  
  # Download Google Drive DMG
  log "Downloading Google Drive..."
  echo "${BOLD}Downloading Google Drive...${RESET}"
  curl -L -o "$TEMP_DIR/GoogleDrive.dmg" "https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
  
  if [ $? -ne 0 ]; then
    log "${RED}ERROR: Failed to download Google Drive${RESET}"
    echo "${RED}Installation failed: Could not download Google Drive.${RESET}"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  # Mount the DMG
  log "Mounting Google Drive disk image..."
  echo "${BOLD}Mounting disk image...${RESET}"
  hdiutil mount -nobrowse "$TEMP_DIR/GoogleDrive.dmg"
  
  if [ $? -ne 0 ]; then
    log "${RED}ERROR: Failed to mount Google Drive disk image${RESET}"
    echo "${RED}Installation failed: Could not mount Google Drive disk image.${RESET}"
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  # Install the package
  log "Installing Google Drive package..."
  echo "${BOLD}Installing Google Drive...${RESET}"
  installer -pkg "/Volumes/Install Google Drive/GoogleDrive.pkg" -target "/"
  INSTALLER_RESULT=$?
  
  # Unmount the DMG
  log "Unmounting Google Drive disk image..."
  hdiutil unmount "/Volumes/Install Google Drive/" -force
  
  # Clean up
  log "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  
  # Check installation result
  if [ $INSTALLER_RESULT -eq 0 ]; then
    log "${GREEN}Google Drive installation SUCCESSFUL!${RESET}"
    echo "${GREEN}Google Drive has been successfully installed!${RESET}"
    exit 0
  else
    log "${RED}ERROR: Google Drive installation failed with exit code $INSTALLER_RESULT${RESET}"
    echo "${RED}Google Drive installation FAILED. Check log at $LOG_FILE for details.${RESET}"
    exit $INSTALLER_RESULT
  fi
else
  log "User chose not to install Google Drive."
  echo "Google Drive will not be installed."
  exit $UNINSTALL_STATUS
fi
