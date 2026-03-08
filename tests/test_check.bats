#!/usr/bin/env bats

set -Eeuo pipefail

load test_helper

setup() {
    setup_test_environment

    # Create test profile
    create_test_profile "test-profile" '{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com"
  }
}'

    # Mock sudo to not actually require privileges in tests
    sudo() {
        # Just pass through the command without actually running sudo
        shift
        "$@"
    }
    export -f sudo
}

teardown() {
    cleanup_test_environment
}

@test "ccsw_check with no active profile" {
    unset CLAUDE_CONFIG_DIR

    run ccsw_check

    [ "$status" -eq 2 ]
    [[ "$output" == *"No active profile found"* ]]
}

@test "ccsw_check with active profile but no config file" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Remove config file
    rm -f "$CCSW_PROFILES_DIR/test-profile/settings.json"

    run ccsw_check

    [ "$status" -eq 1 ]
    [[ "$output" == *"ANTHROPIC_BASE_URL not found"* ]]
}

@test "ccsw_check with valid config and hostname parsing" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection to use ss
    detect_network_tool() {
        echo "ss"
    }

    # Mock network traffic check to return success
    check_network_traffic() {
        echo "mock network check"
        return 0
    }

    run ccsw_check

    [ "$status" -eq 0 ]
    [[ "$output" == *"mock network check"* ]]
}

@test "ccsw_check with invalid URL in config" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Update config with invalid URL
    cat > "$CCSW_PROFILES_DIR/test-profile/settings.json" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "not-a-valid-url"
  }
}
EOF

    run ccsw_check

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to parse hostname"* ]]
}

@test "ccsw_check missing network tools" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection to return no tools
    detect_network_tool() {
        echo ""
        return 1
    }

    run ccsw_check

    [ "$status" -eq 1 ]
    [[ "$output" == *"No supported network tool found"* ]]
}

@test "parse_url_hostname function" {
    # Test various URL formats
    run parse_url_hostname "https://api.anthropic.com/v1"
    [ "$output" == "api.anthropic.com" ]

    run parse_url_hostname "http://localhost:8080"
    [ "$output" == "localhost" ]

    run parse_url_hostname "https://example.com/path/to/resource"
    [ "$output" == "example.com" ]

    run parse_url_hostname "invalid-url"
    [ "$output" == "invalid-url" ]

    run parse_url_hostname ""
    [ "$output" == "" ]
}

@test "detect_network_tool function" {
    # Test with tcpdump available
    command -v tcpdump >/dev/null 2>&1 && {
        run detect_network_tool
        [ "$output" == "tcpdump" ]
    }

    # Test with ss available
    command -v ss >/dev/null 2>&1 && {
        run detect_network_tool
        [ "$output" == "ss" ]
    }
}

@test "check_sudo_privileges function" {
    # Test without sudo (should fail)
    unset EUID
    if [[ $(id -u) -eq 0 ]]; then
        # Root user
        run check_sudo_privileges
        [ "$status" -eq 0 ]
    else
        # Non-root user
        run check_sudo_privileges
        [ "$status" -eq 1 ]
    fi
}

@test "read_anthropic_base_url function" {
    # Test with valid config
    run read_anthropic_base_url "test-profile"
    [ "$status" -eq 0 ]
    [ "$output" == "https://api.anthropic.com" ]

    # Test with non-existent profile
    run read_anthropic_base_url "non-existent-profile"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Profile not found"* ]]
}

@test "ccsw_check network verification failure" {
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/test-profile"

    # Mock network detection
    detect_network_tool() {
        echo "ss"
    }

    # Mock network traffic check to return failure
    check_network_traffic() {
        echo "Network check failed"
        return 1
    }

    run ccsw_check

    [ "$status" -eq 1 ]
    [[ "$output" == *"Network verification failed"* ]]
}
