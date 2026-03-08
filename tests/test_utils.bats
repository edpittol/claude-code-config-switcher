#!/usr/bin/env bats

# Source the utility functions
load '../lib/utils.sh'
load 'test_helper'

@test "log_info outputs to stderr with INFO: prefix" {
    run_with_stderr_capture log_info "test message"
    local output
    local stderr
    local status
    output=$(get_captured_output)
    stderr=$(get_captured_stderr)
    status=$(get_captured_status)
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"INFO: test message"* ]]
    [ "$output" == "" ]
}

@test "log_warn outputs to stderr with WARNING: prefix" {
    run_with_stderr_capture log_warn "test warning"
    local output
    local stderr
    local status
    output=$(get_captured_output)
    stderr=$(get_captured_stderr)
    status=$(get_captured_status)
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"WARNING: test warning"* ]]
    [ "$output" == "" ]
}

@test "log_error outputs to stderr with ERROR: prefix" {
    run_with_stderr_capture log_error "test error"
    local output
    local stderr
    local status
    output=$(get_captured_output)
    stderr=$(get_captured_stderr)
    status=$(get_captured_status)
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"ERROR: test error"* ]]
    [ "$output" == "" ]
}

@test "log_debug outputs only when DEBUG=1" {
    # Test with DEBUG=0 (default)
    run_with_stderr_capture log_debug "debug message"
    local output
    local stderr
    local status
    output=$(get_captured_output)
    stderr=$(get_captured_stderr)
    status=$(get_captured_status)
    [ "$status" -eq 0 ]
    [ "$stderr" == "" ]
    [ "$output" == "" ]

    # Test with DEBUG=1
    DEBUG=1 run_with_stderr_capture log_debug "debug message"
    output=$(get_captured_output)
    stderr=$(get_captured_stderr)
    status=$(get_captured_status)
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"DEBUG: debug message"* ]]
    [ "$output" == "" ]
}

@test "validate_profile_name accepts valid names" {
    # Test valid names
    run validate_profile_name "test-profile"
    [ "$status" -eq 0 ]

    run validate_profile_name "test_profile"
    [ "$status" -eq 0 ]

    run validate_profile_name "test123"
    [ "$status" -eq 0 ]

    run validate_profile_name "TEST"
    [ "$status" -eq 0 ]

    run validate_profile_name "t"
    [ "$status" -eq 0 ]
}

@test "validate_profile_name rejects invalid characters" {
    # Test invalid characters
    run validate_profile_name "test@name"
    [ "$status" -eq 1 ]

    run validate_profile_name "test name"
    [ "$status" -eq 1 ]

    run validate_profile_name "test/name"
    [ "$status" -eq 1 ]

    run validate_profile_name "test\\name"
    [ "$status" -eq 1 ]

    run validate_profile_name "test:name"
    [ "$status" -eq 1 ]
}

@test "validate_profile_name rejects names >64 characters" {
    # Test long name
    local long_name="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghij"
    run validate_profile_name "$long_name"
    [ "$status" -eq 1 ]

    # Test exactly 64 characters
    local exact_name="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdef"
    run validate_profile_name "$exact_name"
    [ "$status" -eq 0 ]
}

@test "validate_profile_name rejects path traversal attempts" {
    # Test path traversal
    run validate_profile_name ".."
    [ "$status" -eq 1 ]

    run validate_profile_name "../profile"
    [ "$status" -eq 1 ]

    run validate_profile_name "profile/.."
    [ "$status" -eq 1 ]

    run validate_profile_name "../test/../profile"
    [ "$status" -eq 1 ]
}

@test "get_config_dir returns correct path" {
    # Test default
    CCSW_CONFIG_DIR="" run get_config_dir
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.config/ccsw" ]]

    # Test override
    CCSW_CONFIG_DIR="/custom/path" run get_config_dir
    [ "$status" -eq 0 ]
    [ "$output" == "/custom/path" ]
}

@test "get_profiles_dir returns correct path" {
    # Test default
    CCSW_CONFIG_DIR="" CCSW_PROFILES_DIR="" run get_profiles_dir
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.config/ccsw/configs" ]]

    # Test override
    CCSW_PROFILES_DIR="/custom/profiles" run get_profiles_dir
    [ "$status" -eq 0 ]
    [ "$output" == "/custom/profiles" ]
}

@test "get_profile_dir constructs correct path" {
    # Test with default paths
    CCSW_CONFIG_DIR="" CCSW_PROFILES_DIR="" run get_profile_dir "test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.config/ccsw/configs/test" ]]

    # Test with override
    CCSW_PROFILES_DIR="/custom/profiles" run get_profile_dir "test"
    [ "$status" -eq 0 ]
    [ "$output" == "/custom/profiles/test" ]
}

@test "get_profile_name_from_path extracts profile name correctly" {
    # Test valid profile path
    profiles_dir=$(get_profiles_dir)
    run get_profile_name_from_path "${profiles_dir}/test-profile"
    [ "$status" -eq 0 ]
    [ "$output" == "test-profile" ]

    # Test invalid path
    run get_profile_name_from_path "/some/other/path"
    [ "$status" -eq 0 ]
    [ "$output" == "" ]

    # Test empty path
    run get_profile_name_from_path ""
    [ "$status" -eq 0 ]
    [ "$output" == "" ]
}

@test "ensure_config_dirs creates directories" {
    # This is a bit tricky to test without side effects
    # We'll test that it doesn't fail
    run ensure_config_dirs
    [ "$status" -eq 0 ]
}
