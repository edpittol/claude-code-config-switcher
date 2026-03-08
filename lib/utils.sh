#!/usr/bin/env bash

set -Eeuo pipefail

# Logging functions
log_info() {
    echo "INFO: $1" >&2
}

log_warn() {
    echo "WARNING: $1" >&2
}

log_error() {
    echo "ERROR: $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "DEBUG: $1" >&2
    fi
}

# Profile name validation
validate_profile_name() {
    local name="$1"

    # Check length (max 64 characters)
    if [[ ${#name} -gt 64 ]]; then
        return 1
    fi

    # Check for valid characters (a-zA-Z0-9_-)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi

    # Check for path traversal attempts
    if [[ "$name" == *..* ]] || [[ "$name" == */* ]] || [[ "$name" == *\\* ]]; then
        return 1
    fi

    return 0
}

# Configuration directory functions
get_config_dir() {
    if [[ -n "${CCSW_CONFIG_DIR:-}" ]]; then
        echo "$CCSW_CONFIG_DIR"
    else
        echo "${HOME}/.config/ccsw"
    fi
}

get_profiles_dir() {
    local config_dir
    config_dir=$(get_config_dir)

    if [[ -n "${CCSW_PROFILES_DIR:-}" ]]; then
        echo "$CCSW_PROFILES_DIR"
    else
        echo "${config_dir}/configs"
    fi
}

get_profile_dir() {
    local profile_name="$1"
    local profiles_dir
    profiles_dir=$(get_profiles_dir)
    echo "${profiles_dir}/${profile_name}"
}

get_profile_name_from_path() {
    local path="$1"
    local profiles_dir
    profiles_dir=$(get_profiles_dir)

    # Extract the profile name from the path
    local profile_name="${path##*/}"

    # Check if the path starts with profiles_dir and has a profile name
    if [[ "$path" == "${profiles_dir%/}/${profile_name}" ]]; then
        echo "$profile_name"
    else
        echo ""
    fi
}

ensure_config_dirs() {
    local config_dir
    local profiles_dir

    config_dir=$(get_config_dir)
    profiles_dir=$(get_profiles_dir)

    # Create config directory if it doesn't exist
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
    fi

    # Create profiles directory if it doesn't exist
    if [[ ! -d "$profiles_dir" ]]; then
        mkdir -p "$profiles_dir"
    fi
}



