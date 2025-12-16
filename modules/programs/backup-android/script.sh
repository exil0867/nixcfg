#!/bin/bash
set -e

# Configuration
DATE=$(date +%Y-%m-%d_%H-%M-%S)
DEFAULT_BACKUP_DIR="android_backup_$DATE"
SSH_PORT=2222
SSH_USER="ssh"

# Folder lists
INTERNAL_FOLDERS=(Alarms Audiobooks DCIM Documents Download Flexify GCam KeePassVault "KeePassVault (1)" Mihon Movies Music Notifications OpenContacts OpenTracks Pictures Podcasts Recordings Ringtones SGCAM Soulseek SpMp Valv koreader panoramas xManager)
EXTERNAL_FOLDERS=(Alarms Audiobooks DCIM Documents Download Movies Music Notifications Pictures Podcasts Recordings Ringtones)
JSON_FILE="UW_Backup_Wallet_2024-10-16_02-01.json"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() { echo -e "${RED}[!] $1${NC}"; }
print_success() { echo -e "${GREEN}[+] $1${NC}"; }
print_info() { echo -e "${YELLOW}[*] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --internal        Backup internal storage via ADB"
    echo "  -e, --external        Backup external SD card via SFTP"
    echo "  -a, --all             Backup both internal and external (default)"
    echo "  --all-contents        Backup EVERYTHING (not just predefined folders)"
    echo "  -o, --output PATH     Custom output directory (default: ./android_backup_DATE)"
    echo "  --root                Use root access via 'adb root' (requires rooted device)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --internal              # Only predefined internal folders"
    echo "  $0 --external              # Only predefined external folders"
    echo "  $0 --internal --all-contents  # ALL internal storage contents"
    echo "  $0 -o /mnt/backups/phone   # Custom output path"
    echo "  $0 --all-contents          # Everything from both storages"
    echo "  $0                         # Both storages (predefined folders only)"
    exit 1
}

# Parse arguments
BACKUP_INTERNAL=false
BACKUP_EXTERNAL=false
BACKUP_ALL_CONTENTS=false
BACKUP_DIR=""
USE_ROOT=false

if [ $# -eq 0 ]; then
    BACKUP_INTERNAL=true
    BACKUP_EXTERNAL=true
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--internal)
                BACKUP_INTERNAL=true
                shift
                ;;
            -e|--external)
                BACKUP_EXTERNAL=true
                shift
                ;;
            -a|--all)
                BACKUP_INTERNAL=true
                BACKUP_EXTERNAL=true
                shift
                ;;
            --all-contents)
                BACKUP_ALL_CONTENTS=true
                shift
                ;;
            -o|--output)
                if [ -z "$2" ]; then
                    print_error "Output path requires an argument"
                    usage
                fi
                BACKUP_DIR="$2"
                shift 2
                ;;
            --root)
                USE_ROOT=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
fi

# Set backup directory
if [ -z "$BACKUP_DIR" ]; then
    BACKUP_DIR="$DEFAULT_BACKUP_DIR"
fi

# Create main backup directory
mkdir -p "$BACKUP_DIR"
print_info "Backup directory: $BACKUP_DIR"

# Permission error counter
PERMISSION_ERRORS=0

# ============================================================================
# INTERNAL STORAGE BACKUP (ADB)
# ============================================================================
backup_internal() {
    print_info "Starting INTERNAL storage backup via ADB..."

    # Check ADB connection
    if ! adb get-state &>/dev/null; then
        print_error "No ADB device connected. Please connect and authorize your device."
        return 1
    fi

    print_success "ADB device detected"

    # Enable root if requested
    if [ "$USE_ROOT" = true ]; then
        print_info "Attempting to restart ADB with root privileges..."
        if adb root 2>&1 | grep -q "cannot run as root"; then
            print_error "Device does not support 'adb root'"
            print_error "Your device needs to be rooted with an unlocked bootloader"
            return 1
        fi
        # Wait for daemon to restart
        sleep 2
        if ! adb get-state &>/dev/null; then
            print_error "Lost connection after adb root. Reconnecting..."
            sleep 2
        fi
        print_success "ADB running as root"
    fi

    # Detect user IDs
    USER_IDS=($(adb shell pm list users 2>/dev/null | grep -oP 'UserInfo\{\K\d+' || echo "0"))
    print_info "Detected user profiles: ${USER_IDS[*]}"

    for USER_ID in "${USER_IDS[@]}"; do
        if [ "$USER_ID" -eq 0 ]; then
            PREFIX="/sdcard"
            LABEL="owner"
        else
            PREFIX="/storage/emulated/$USER_ID"
            LABEL="profile-$USER_ID"
        fi

        mkdir -p "$BACKUP_DIR/internal/$LABEL"
        print_info "Backing up $LABEL..."

        if [ "$BACKUP_ALL_CONTENTS" = true ]; then
            # Backup EVERYTHING with error handling
            print_info "  → Backing up ENTIRE storage (this may take a while)..."
            print_warning "  → Some system files may be inaccessible (expected)"
            
            # Capture both stdout and stderr
            PULL_OUTPUT=$(adb pull "$PREFIX/" "$BACKUP_DIR/internal/$LABEL/" 2>&1 || true)
            
            # Count permission errors
            PERM_COUNT=$(echo "$PULL_OUTPUT" | grep -c "Permission denied" || true)
            if [ "$PERM_COUNT" -gt 0 ]; then
                PERMISSION_ERRORS=$((PERMISSION_ERRORS + PERM_COUNT))
                print_warning "  → Skipped $PERM_COUNT files/folders due to permissions"
            fi
            
            # Check if we got anything
            if [ -d "$BACKUP_DIR/internal/$LABEL/sdcard" ] || [ -d "$BACKUP_DIR/internal/$LABEL/storage" ]; then
                print_success "  → Backup completed (with permission limitations)"
            else
                print_error "  → No files were backed up"
            fi
        else
            # Backup only predefined folders
            for F in "${INTERNAL_FOLDERS[@]}"; do
                echo "  → $F"
                PULL_OUTPUT=$(adb pull "$PREFIX/$F" "$BACKUP_DIR/internal/$LABEL/$F" 2>&1 || true)
                
                if echo "$PULL_OUTPUT" | grep -q "Permission denied"; then
                    print_warning "    (permission denied)"
                    PERMISSION_ERRORS=$((PERMISSION_ERRORS + 1))
                elif echo "$PULL_OUTPUT" | grep -q "does not exist"; then
                    echo "    (not found)"
                fi
            done

            # Backup JSON file
            echo "  → $JSON_FILE"
            adb pull "$PREFIX/$JSON_FILE" "$BACKUP_DIR/internal/$LABEL/$JSON_FILE" 2>/dev/null || \
                echo "    (not found)"
        fi
    done

    print_success "Internal backup completed"
}

# ============================================================================
# EXTERNAL STORAGE BACKUP (SFTP)
# ============================================================================
backup_external() {
    print_info "Starting EXTERNAL SD card backup via SFTP..."

    # Auto-detect phone IP
    print_info "Detecting phone IP address..."
    PHONE_IP=$(adb shell ip addr show wlan0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)

    if [ -z "$PHONE_IP" ]; then
        print_error "Could not detect phone IP address via ADB"
        read -p "Enter phone IP manually (or press Enter to skip): " MANUAL_IP
        if [ -z "$MANUAL_IP" ]; then
            print_error "Skipping external backup"
            return 1
        fi
        PHONE_IP="$MANUAL_IP"
    fi

    print_info "Phone IP: $PHONE_IP"

    # Add host key first
    print_info "Adding host key..."
    ssh-keyscan -p $SSH_PORT -H $PHONE_IP >> ~/.ssh/known_hosts 2>/dev/null || true

    # Check if sshpass is installed
    if ! command -v sshpass &> /dev/null; then
        print_error "sshpass is not installed. Install it with:"
        print_error "  Ubuntu/Debian: sudo apt install sshpass"
        print_error "  Arch: sudo pacman -S sshpass"
        print_error "  macOS: brew install hudochenkov/sshpass/sshpass"
        return 1
    fi

    # Create SFTP batch file first
    SFTP_BATCH=$(mktemp)
    trap 'rm -f "$SFTP_BATCH"' EXIT

    mkdir -p "$BACKUP_DIR/external"
    echo "lcd $BACKUP_DIR/external" >> "$SFTP_BATCH"

    if [ "$BACKUP_ALL_CONTENTS" = true ]; then
        # Backup EVERYTHING from SD card
        print_info "Preparing to download ENTIRE SD card..."
        echo "get -r *" >> "$SFTP_BATCH"
    else
        # Backup only predefined folders
        print_info "Preparing folder list..."
        for folder in "${EXTERNAL_FOLDERS[@]}"; do
            echo "get -r \"$folder\"" >> "$SFTP_BATCH"
        done
    fi
    echo "bye" >> "$SFTP_BATCH"

    # Get password - must use immediately
    print_info "Check your phone for the one-time password"
    print_info "IMPORTANT: Enter password and press Enter immediately!"
    read -sp "Enter SSH password: " SSH_PASS
    echo ""

    # Execute SFTP immediately (don't test first, password expires quickly)
    print_info "Connecting and downloading SD card contents..."
    SFTP_OUTPUT=$(sshpass -p "$SSH_PASS" sftp -P $SSH_PORT -o StrictHostKeyChecking=accept-new \
       -b "$SFTP_BATCH" $SSH_USER@$PHONE_IP 2>&1)

    # Check if connection succeeded
    if echo "$SFTP_OUTPUT" | grep -q "Permission denied"; then
        print_error "Password authentication failed"
        print_error "Password may have expired - one-time passwords are usually valid for ~30 seconds"
        print_error "Try again and enter the password immediately when prompted"
        return 1
    elif echo "$SFTP_OUTPUT" | grep -q "Connection refused\|No route to host"; then
        print_error "Cannot connect to $PHONE_IP:$SSH_PORT"
        print_error "Make sure SSH server is running on your phone"
        return 1
    else
        print_success "External backup completed"
        # Show what was downloaded
        echo "$SFTP_OUTPUT" | grep -i "fetching\|downloading" || true
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
print_info "=== Android Backup Script ==="
print_info "Backup modes: Internal=$BACKUP_INTERNAL, External=$BACKUP_EXTERNAL, All Contents=$BACKUP_ALL_CONTENTS"
if [ "$USE_ROOT" = true ]; then
    print_warning "Root mode enabled - will access system files"
fi
echo ""

if [ "$BACKUP_INTERNAL" = true ]; then
    backup_internal || print_error "Internal backup failed"
    echo ""
fi

if [ "$BACKUP_EXTERNAL" = true ]; then
    backup_external || print_error "External backup failed"
    echo ""
fi

# Summary
print_success "=== Backup Summary ==="
print_info "Backup location: $(realpath "$BACKUP_DIR")"

if [ "$BACKUP_INTERNAL" = true ] && [ -d "$BACKUP_DIR/internal" ]; then
    INTERNAL_SIZE=$(du -sh "$BACKUP_DIR/internal" 2>/dev/null | cut -f1)
    print_info "Internal storage: $INTERNAL_SIZE"
fi

if [ "$BACKUP_EXTERNAL" = true ] && [ -d "$BACKUP_DIR/external" ]; then
    EXTERNAL_SIZE=$(du -sh "$BACKUP_DIR/external" 2>/dev/null | cut -f1)
    print_info "External SD card: $EXTERNAL_SIZE"
fi

if [ "$PERMISSION_ERRORS" -gt 0 ]; then
    print_warning "Note: $PERMISSION_ERRORS files/folders were skipped due to permissions"
    print_info "This is normal for Android system files and app-private data"
fi

print_success "All done!"