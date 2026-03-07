#!/usr/bin/env bash

set -Eeuo pipefail

# Source utility functions
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Network inspection tool detection
detect_network_tool() {
    # Check for tcpdump first (more comprehensive)
    if command -v tcpdump >/dev/null 2>&1; then
        echo "tcpdump"
        return 0
    fi

    # Fall back to ss (socket statistics)
    if command -v ss >/dev/null 2>&1; then
        echo "ss"
        return 0
    fi

    # No supported network tool found
    echo ""
    return 1
}

# Parse URL to extract hostname
parse_url_hostname() {
    local url="$1"

    # Remove protocol prefix
    url="${url#http://}"
    url="${url#https://}"

    # Remove path and query string
    url="${url%%/*}"

    # Remove port if present
    url="${url%%:*}"

    echo "$url"
}

# Check if running with sudo privileges
check_sudo_privileges() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Try to run sudo with a harmless command
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    return 1
}

# Check network traffic using tcpdump
check_traffic_with_tcpdump() {
    local hostname="$1"
    local interface="${2:-any}"
    local timeout="${3:-10}"

    log_debug "Checking traffic to $hostname using tcpdump on interface $interface"

    # Create temporary file for capturing output
    local temp_file
    temp_file=$(mktemp)

    # Set trap to clean up
    trap 'rm -f "$temp_file"' EXIT

    # Run tcpdump in background
    local tcpdump_cmd="sudo tcpdump -i $interface -c 1 -w $temp_file host $hostname 2>/dev/null &"
    log_debug "Executing: $tcpdump_cmd"

    # Start tcpdump
    eval "$tcpdump_cmd"
    local tcpdump_pid=$!

    # Wait for timeout or completion
    local count=0
    while [[ $count -lt $timeout ]]; do
        if ! kill -0 "$tcpdump_pid" 2>/dev/null; then
            # tcpdump finished
            break
        fi
        sleep 1
        count=$((count + 1))
    done

    # Kill tcpdump if still running
    if kill -0 "$tcpdump_pid" 2>/dev/null; then
        sudo kill "$tcpdump_pid" 2>/dev/null || true
    fi

    # Check if we captured any packets
    if [[ -s "$temp_file" ]]; then
        log_debug "Traffic to $hostname detected"
        rm -f "$temp_file"
        return 0
    else
        log_debug "No traffic to $hostname detected"
        rm -f "$temp_file"
        return 1
    fi
}

# Check network traffic using ss
check_traffic_with_ss() {
    local hostname="$1"
    local timeout="${2:-10}"

    log_debug "Checking traffic to $hostname using ss"

    # Wait for timeout and check connections
    sleep "$timeout"

    # Look for hostname in current connections
    if ss -t | grep -E "(ESTABLISHED|TIME_WAIT)" | grep -q "$hostname"; then
        log_debug "Traffic to $hostname detected"
        return 0
    else
        log_debug "No traffic to $hostname detected"
        return 1
    fi
}

# Main network traffic check function
check_network_traffic() {
    local hostname="$1"
    local tool="${2:-}"
    local interface="${3:-any}"
    local timeout="${4:-10}"

    log_info "Checking network traffic to $hostname"

    # Validate hostname
    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty"
        return 1
    fi

    # Auto-detect network tool if not provided
    if [[ -z "$tool" ]]; then
        tool=$(detect_network_tool)
        if [[ -z "$tool" ]]; then
            log_error "No supported network tool found. Please install tcpdump or ss."
            return 1
        fi
        log_debug "Using network tool: $tool"
    fi

    # Check sudo privileges
    if [[ "$tool" == "tcpdump" ]] && ! check_sudo_privileges; then
        log_error "tcpdump requires sudo privileges"
        return 3
    fi

    # Perform traffic check based on available tool
    case "$tool" in
        "tcpdump")
            check_traffic_with_tcpdump "$hostname" "$interface" "$timeout"
            ;;
        "ss")
            check_traffic_with_ss "$hostname" "$timeout"
            ;;
        *)
            log_error "Unsupported network tool: $tool"
            return 1
            ;;
    esac

    local result=$?

    if [[ $result -eq 0 ]]; then
        log_info "Traffic verification successful: $hostname"
    else
        log_warn "No traffic detected to: $hostname"
    fi

    return $result
}

# Read ANTHROPIC_BASE_URL from profile config
read_anthropic_base_url() {
    local profile="$1"
    local profile_dir
    local config_file

    # Get profile directory
    profile_dir=$(get_profile_dir "$profile")

    # Check if profile directory exists
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile not found: $profile"
        return 1
    fi

    # Settings file path (Claude Code uses settings.json)
    config_file="${profile_dir}/settings.json"

    # Check if settings file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Settings file not found: $config_file"
        return 1
    fi

    # Extract ANTHROPIC_BASE_URL using jq if available
    if command -v jq >/dev/null 2>&1; then
        local url
        url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$config_file" 2>/dev/null)
        if [[ -n "$url" && "$url" != "null" ]]; then
            echo "$url"
            return 0
        fi
    fi

    # Fallback: grep from file (less robust)
    local url
    url=$(grep -o '"ANTHROPIC_BASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f4)
    if [[ -n "$url" ]]; then
        echo "$url"
        return 0
    fi

    # URL not found
    log_error "ANTHROPIC_BASE_URL not found in profile config: $profile"
    return 1
}