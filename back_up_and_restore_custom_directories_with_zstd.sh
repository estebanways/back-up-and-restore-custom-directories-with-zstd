#!/usr/bin/env bash

# ------------------------------------------------------------
# Script Name: Backup and Restore Custom Directories
# Author:      Esteban Herrera Castro
# Email:       stv.herrera@gmail.com
# Date:        05/21/2025
# ------------------------------------------------------------
# Description:
# This script ...from the archive.
#
#
# ------------------------------------------------------------

# Define output file
backup_file="dirs_backup.tar.zst"

# List of directories to back up
dirs=(
    "$HOME/.config/BraveSoftware/"
    "$HOME/config/"
    "$HOME/.local/share/nvim/site/"
    "$HOME/Dev/"
    "$HOME/DevDocs/"
    "$HOME/Documents/"
    "$HOME/Downloads/"
    "/etc/"
)

# Create compressed archive using tar + zstd
sudo tar -cv --use-compress-program=zstd -f "$backup_file" "${dirs[@]}" 2>dirs.log

# Verify the archive was created
if [ -f "$backup_file" ]; then
    echo "✅ Backup created: $backup_file"
else
    echo "❌ Backup failed! Check dirs.log for errors."
fi

# Automate verification
# Silent corruption can happen due to disk errors or interrupted writes
# zstd -t is the fastest way to check integrity
# For mission-critical data, use checksums method
if zstd -t "$backup_file"; then
    echo "✅ Archive is valid and intact."
else
    echo "❌ Archive is corrupted! Check 'dirs.log'."
fi


# Extraction instructions
echo -e "\nTo extract this backup later, run:"
echo "sudo tar -xvf $backup_file --use-compress-program=zstd -C /target/dir/"
