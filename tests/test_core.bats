#!/usr/bin/env bats

# Source the utility functions and core functions
load '../lib/utils.sh'
load '../lib/core.sh'

# Setup test environment
setup() {
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)

    # Override config directory for testing
    export CCSW_CONFIG_DIR="$TEST_DIR/.config/ccsw"
    export CCSW_PROFILES_DIR="$CCSW_CONFIG_DIR/configs"

    # Create profiles directory
    mkdir -p "$CCSW_PROFILES_DIR"

    # Create test profiles
    mkdir -p "$CCSW_PROFILES_DIR/profile1"
    mkdir -p "$CCSW_PROFILES_DIR/profile2"
    mkdir -p "$CCSW_PROFILES_DIR/TestProfile"

    # Create some content in profiles
    echo "# Test configuration" > "$CCSW_PROFILES_DIR/profile1/settings.json"
    echo "# Test configuration" > "$CCSW_PROFILES_DIR/profile2/settings.json"
}

# Cleanup test environment
teardown() {
    # Remove temporary test directory
    rm -rf "$TEST_DIR"

    # Unset environment variables
    unset CCSW_CONFIG_DIR
    unset CCSW_PROFILES_DIR
}

@test "ccsw_list lists profiles alphabetically" {
    run ccsw_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"profile1"* ]]
    [[ "$output" == *"profile2"* ]]
    [[ "$output" == *"TestProfile"* ]]
    # Check that output is sorted (case-insensitive)
    [[ "$(echo "$output" | sort -f | tr '\n' ' ')" == "$(printf 'profile1 profile2 TestProfile ' | sort -f)" ]]
}

@test "ccsw_list returns exit code 1 when no profiles" {
    # Remove all profiles
    rm -rf "$CCSW_PROFILES_DIR"/*
    rmdir "$CCSW_PROFILES_DIR"

    run ccsw_list
    [ "$status" -eq 1 ]
    [ "$output" == "" ]
}

@test "ccsw_list returns exit code 1 when profiles directory doesn't exist" {
    # Remove profiles directory
    rm -rf "$CCSW_PROFILES_DIR"

    run ccsw_list
    [ "$status" -eq 1 ]
    [ "$output" == "" ]
}

@test "ccsw_use outputs export statement" {
    run ccsw_use "profile1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"export CLAUDE_CONFIG_DIR=$CCSW_PROFILES_DIR/profile1" ]]
}

@test "ccsw_use returns exit code 1 for non-existent profile" {
    run ccsw_use "nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Profile not found: nonexistent" ]]
}

@test "ccsw_use returns exit code 1 for invalid profile name" {
    run ccsw_use "@invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Invalid profile name: @invalid" ]]
}

@test "ccsw_use idempotent (same profile succeeds)" {
    # First use
    run ccsw_use "profile1"
    [ "$status" -eq 0 ]

    # Second use of same profile
    run ccsw_use "profile1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"export CLAUDE_CONFIG_DIR=$CCSW_PROFILES_DIR/profile1" ]]
}

@test "ccsw_current shows profile name when set" {
    # Set CLAUDE_CONFIG_DIR to a profile
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/profile1"

    run ccsw_current
    [ "$status" -eq 0 ]
    [ "$output" == "profile1" ]
}

@test "ccsw_current shows 'No active profile' when CLAUDE_CONFIG_DIR unset" {
    unset CLAUDE_CONFIG_DIR

    run ccsw_current
    [ "$status" -eq 0 ]
    [ "$output" == "No active profile" ]
}

@test "ccsw_current returns exit code 3 for external directory" {
    # Set CLAUDE_CONFIG_DIR to an external directory
    export CLAUDE_CONFIG_DIR="/tmp/external"

    run ccsw_current
    [ "$status" -eq 3 ]
    [[ "$output" == *"External: /tmp/external" ]]
}

@test "ccsw_current warns on external directory" {
    # Set CLAUDE_CONFIG_DIR to an external directory
    export CLAUDE_CONFIG_DIR="/tmp/external"

    run ccsw_current
    [ "$status" -eq 3 ]
    [[ "$stderr" == *"WARNING: CLAUDE_CONFIG_DIR points to external directory: /tmp/external" ]]
}

@test "ccsw_current handles empty profiles directory" {
    # Create empty profiles directory
    mkdir -p "$CCSW_PROFILES_DIR"

    # Set CLAUDE_CONFIG_DIR to profiles dir (edge case)
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR"

    run ccsw_current
    [ "$status" -eq 0 ]
    [ "$output" == "No active profile" ]
}

@test "ccsw_delete removes profile directory" {
    local profile_dir="$CCSW_PROFILES_DIR/profile1"

    # Verify profile exists before deletion
    [ -d "$profile_dir" ]

    run ccsw_delete "profile1"
    [ "$status" -eq 0 ]
    [ ! -d "$profile_dir" ]
}

@test "ccsw_delete returns exit code 1 for non-existent profile" {
    run ccsw_delete "nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Profile not found: nonexistent" ]]
}

@test "ccsw_delete returns exit code 1 for invalid profile name" {
    run ccsw_delete "@invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Invalid profile name: @invalid" ]]
}

@test "ccsw_delete prevents deleting active profile (exit code 2)" {
    # Set CLAUDE_CONFIG_DIR to profile1
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/profile1"

    run ccsw_delete "profile1"
    [ "$status" -eq 2 ]
    [[ "$output" == *"ERROR: Cannot delete active profile: profile1" ]]

    # Verify profile still exists
    [ -d "$CCSW_PROFILES_DIR/profile1" ]
}

@test "ccsw_delete works when CLAUDE_CONFIG_DIR is unset" {
    unset CLAUDE_CONFIG_DIR

    local profile_dir="$CCSW_PROFILES_DIR/profile1"
    [ -d "$profile_dir" ]

    run ccsw_delete "profile1"
    [ "$status" -eq 0 ]
    [ ! -d "$profile_dir" ]
}

@test "ccsw_delete works when CLAUDE_CONFIG_DIR points to different profile" {
    # Set CLAUDE_CONFIG_DIR to profile2
    export CLAUDE_CONFIG_DIR="$CCSW_PROFILES_DIR/profile2"

    local profile_dir="$CCSW_PROFILES_DIR/profile1"
    [ -d "$profile_dir" ]

    run ccsw_delete "profile1"
    [ "$status" -eq 0 ]
    [ ! -d "$profile_dir" ]
}

@test "ccsw_list handles empty profile names" {
    # Create profile with empty name (should not happen but test defensive)
    mkdir -p "$CCSW_PROFILES_DIR/.empty"

    run ccsw_list
    [ "$status" -eq 0 ]
    # .empty should not be listed as it's not a valid profile name
    [[ "$output" != *".empty" ]]
}

@test "ccsw_use handles profile names with special characters" {
    # Create profile with valid special characters
    mkdir -p "$CCSW_PROFILES_DIR/test-profile"

    run ccsw_use "test-profile"
    [ "$status" -eq 0 ]
    [[ "$output" == *"export CLAUDE_CONFIG_DIR=$CCSW_PROFILES_DIR/test-profile" ]]
}

@test "ccsw_create creates profile directory and outputs path" {
    local new_profile="test-new-profile"
    local expected_path="$CCSW_PROFILES_DIR/$new_profile"

    # Verify profile doesn't exist before creation
    [ ! -d "$expected_path" ]

    run ccsw_create "$new_profile"
    [ "$status" -eq 0 ]
    [ "$output" == "$expected_path" ]
    [ -d "$expected_path" ]
}

@test "ccsw_create returns exit code 1 for invalid profile name" {
    run ccsw_create "@invalid"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Invalid profile name: @invalid" ]]
}

@test "ccsw_create returns exit code 1 for existing profile" {
    run ccsw_create "profile1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Profile already exists: profile1" ]]
}

@test "ccsw_create creates profiles directory if it doesn't exist" {
    # Remove profiles directory
    rm -rf "$CCSW_PROFILES_DIR"

    local new_profile="test-new-profile"
    local expected_path="$CCSW_PROFILES_DIR/$new_profile"

    # Verify profiles directory doesn't exist
    [ ! -d "$CCSW_PROFILES_DIR" ]

    run ccsw_create "$new_profile"
    [ "$status" -eq 0 ]
    [ "$output" == "$expected_path" ]
    [ -d "$expected_path" ]
    [ -d "$CCSW_PROFILES_DIR" ]
}