#!/usr/bin/env bash

# Test helper functions for bats

set -Eeuo pipefail

# Add lib directory to PATH for sourcing
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/../lib"
export PATH="$LIB_DIR:$PATH"

# Source core functions for testing
source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

# Test utilities

# Initialize stderr for tests (fixes unbound variable errors)
init_test_env() {
    export stderr=""
}

setup_test_environment() {
    # Create temporary test directory
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Override config directory for tests
    export CCSW_CONFIG_DIR="$TEST_TEMP_DIR/ccsw"
    export CCSW_PROFILES_DIR="$TEST_TEMP_DIR/ccsw/configs"

    # Create test profiles directory
    mkdir -p "$CCSW_PROFILES_DIR"

    # Mock commands for testing
    mock_command() {
        local cmd="$1"
        local mock_script="$2"

        # Create mock directory if it doesn't exist
        local mock_dir="$TEST_TEMP_DIR/mocks"
        mkdir -p "$mock_dir"

        # Create mock script
        cat > "$mock_dir/$cmd" << EOF
#!/bin/bash
$mock_script
EOF
        chmod +x "$mock_dir/$cmd"

        # Add mock directory to PATH
        export PATH="$mock_dir:$PATH"
    }

    # Unset active profile
    unset CLAUDE_CONFIG_DIR
}

cleanup_test_environment() {
    # Clean up temporary directory
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Mock jq for testing
mock_jq() {
    mock_command "jq" '
        if [[ "$1" == "-r" && "$2" == ".env.ANTHROPIC_BASE_URL" ]]; then
            cat << 'EOF'
https://api.anthropic.com
EOF
        else
            # Default mock behavior for other jq commands
            echo "null"
        fi
    '
}

# Create test profile with config
create_test_profile() {
    local profile_name="$1"
    local config_content="$2"

    local profile_dir="$CCSW_PROFILES_DIR/$profile_name"
    mkdir -p "$profile_dir"

    if [[ -n "$config_content" ]]; then
        echo "$config_content" > "$profile_dir/settings.json"
    fi
}

# Set active profile
set_active_profile() {
    local profile_name="$1"
    local profile_dir="$CCSW_PROFILES_DIR/$profile_name"
    export CLAUDE_CONFIG_DIR="$profile_dir"
}

# Helper function to run command and capture stderr
# This enables proper stderr testing in bats tests
run_with_stderr_capture() {
    # Use temp files to capture stdout and stderr separately
    local stdout_file
    local stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)

    # Run the command, capturing stdout and stderr separately
    "$@" > "$stdout_file" 2> "$stderr_file"

    # Store results in temp files for later reading
    _bats_run_stdout=$stdout_file
    _bats_run_stderr=$stderr_file
    _bats_run_status=$?

    # Clean up will happen when variables are read
}

# Get the output from the last run_with_stderr_capture
get_captured_output() {
    cat "$_bats_run_stdout"
    rm -f "$_bats_run_stdout"
}

# Get the stderr from the last run_with_stderr_capture
get_captured_stderr() {
    cat "$_bats_run_stderr"
    rm -f "$_bats_run_stderr"
}

# Get the status from the last run_with_stderr_capture
get_captured_status() {
    echo "$_bats_run_status"
}
