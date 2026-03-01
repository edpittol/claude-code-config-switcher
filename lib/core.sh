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

# Show the currently active profile from CLAUDE_CONFIG_DIR
ccsw_current() {
    local current_config_dir="${CLAUDE_CONFIG_DIR:-}"
    local profiles_dir
    local profile_name

    # Check if CLAUDE_CONFIG_DIR is set
    if [[ -z "$current_config_dir" ]]; then
        echo "No active profile"
        return 0
    fi

    # Get the profiles directory
    profiles_dir=$(get_profiles_dir)

    # Check if the current config directory is managed by ccsw
    profile_name=$(get_profile_name_from_path "$current_config_dir")

    if [[ -n "$profile_name" ]]; then
        # It's a ccsw-managed profile
        echo "$profile_name"
        return 0
    elif [[ "$current_config_dir" != "$profiles_dir" ]]; then
        # It's an external directory
        echo "External: $current_config_dir"
        log_warn "CLAUDE_CONFIG_DIR points to external directory: $current_config_dir"
        return 3
    else
        # No active profile
        echo "No active profile"
        return 0
    fi
}

# Create a profile directory and output its path
ccsw_create() {
    local profile="$1"
    local profile_dir
    local profiles_dir

    # Validate profile name
    if ! validate_profile_name "$profile"; then
        log_error "Invalid profile name: $profile"
        return 1
    fi

    # Get directories
    profiles_dir=$(get_profiles_dir)
    profile_dir=$(get_profile_dir "$profile")

    # Check if profile already exists
    if [[ -d "$profile_dir" ]]; then
        log_error "Profile already exists: $profile"
        return 1
    fi

    # Create profiles directory if it doesn't exist
    if ! ensure_config_dirs; then
        log_error "Failed to create profiles directory"
        return 1
    fi

    # Create profile directory with proper permissions
    if ! mkdir -p "$profile_dir"; then
        log_error "Failed to create profile directory: $profile"
        return 1
    fi

    # Output the path for eval usage
    echo "$profile_dir"
    return 0
}

# Delete a profile directory with safety guards
ccsw_delete() {
    local profile="$1"
    local profile_dir
    local current_config_dir="${CLAUDE_CONFIG_DIR:-}"

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

    # Check if trying to delete currently active profile
    if [[ -n "$current_config_dir" && "$current_config_dir" == "$profile_dir" ]]; then
        log_error "Cannot delete active profile: $profile"
        return 2
    fi

    # Remove the profile directory
    if ! rm -rf "$profile_dir"; then
        log_error "Failed to delete profile: $profile"
        return 1
    fi

    return 0
}



