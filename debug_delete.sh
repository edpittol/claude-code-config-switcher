#!/usr/bin/env bash

# Debug script for ccsw_delete
set -Eeuo pipefail

source lib/utils.sh
source lib/core.sh

# Create test profile
mkdir -p "$HOME/.config/ccsw/configs/debug-profile"

# Use the profile
unset CLAUDE_CONFIG_DIR
eval "$(ccsw_use debug-profile)"
echo "CLAUDE_CONFIG_DIR: $CLAUDE_CONFIG_DIR"

# Get profile directory
profile_dir=$(get_profile_dir "debug-profile")
echo "Profile dir: $profile_dir"

# Check if they're equal
if [[ "$CLAUDE_CONFIG_DIR" == "$profile_dir" ]]; then
    echo "Directories are EQUAL"
    echo "This should trigger exit code 2"
else
    echo "Directories are NOT EQUAL"
    echo "This should allow deletion"
fi

# Test actual delete
echo "Running ccsw_delete debug-profile..."
ccsw_delete "debug-profile"
echo "Exit code: $?"