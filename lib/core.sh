#!/usr/bin/env bash

set -Eeuo pipefail

# Source utility functions
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# List all available profiles sorted alphabetically
ccsw_list() {
    local profiles_dir
    profiles_dir=$(get_profiles_dir)

    # Check if profiles directory exists
    if [[ ! -d "$profiles_dir" ]]; then
        return 1
    fi

    # Find all profile directories and sort them
    local profiles
    profiles=$(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -f)

    # If no profiles found, return 1
    if [[ -z "$profiles" ]]; then
        return 1
    fi

    # Output each profile on a separate line
    echo "$profiles"
    return 0
}

# Switch to a profile by outputting an export statement
ccsw_use() {
    local profile="$1"
    local profile_dir

    # Validate profile name
    if ! validate_profile_name "$profile"; then
        log_error "Invalid profile name: $profile"
        return 1
    fi

    # Get profile directory
    profile_dir=$(get_profile_dir "$profile")

    # Check if profile directory exists
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile not found: $profile"
        return 1
    fi

    # Output the export statement for eval
    echo "export CLAUDE_CONFIG_DIR=${profile_dir%/}"
    return 0
}