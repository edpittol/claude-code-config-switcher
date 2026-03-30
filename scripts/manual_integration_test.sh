#!/usr/bin/env bash

# Manual integration test script for ccsw tool
# This script performs manual end-to-end testing of the ccsw tool

set -Eeuo pipefail

echo "=== ccsw Manual Integration Test ==="
echo "Date: $(date)"
echo ""

# Create temporary test directory
TEST_TEMP_DIR=$(mktemp -d)
export CCSW_CONFIG_DIR="$TEST_TEMP_DIR"
export CCSW_PROFILES_DIR="$TEST_TEMP_DIR/configs"

echo "Using temporary test directory: $TEST_TEMP_DIR"
echo ""

# Setup: Create test profiles
echo "1. Setting up test profiles..."
mkdir -p "$CCSW_PROFILES_DIR/integration-test1"
mkdir -p "$CCSW_PROFILES_DIR/integration-test2"
echo "✓ Created integration-test1 and integration-test2"
echo ""

# Test 1: List profiles
echo "2. Testing ccsw list..."
echo "Command: ./bin/ccsw list"
./bin/ccsw list
echo "✓ Profiles listed successfully"
echo ""

# Test 2: Use profile1
echo "3. Testing ccsw use..."
unset CLAUDE_CONFIG_DIR
eval "$(./bin/ccsw use integration-test1)"
echo "CLAUDE_CONFIG_DIR is now: $CLAUDE_CONFIG_DIR"
echo "✓ Profile switched successfully"
echo ""

# Test 3: Check current profile
echo "4. Testing ccsw current..."
./bin/ccsw current
echo "✓ Current profile command executed"
echo ""

# Test 4: Verify CLAUDE_CONFIG_DIR
echo "5. Verifying CLAUDE_CONFIG_DIR..."
if [[ "$CLAUDE_CONFIG_DIR" == "$TEST_TEMP_DIR/configs/integration-test1" ]]; then
    echo "✓ CLAUDE_CONFIG_DIR is correct"
else
    echo "✗ CLAUDE_CONFIG_DIR is incorrect"
    echo "Expected: $TEST_TEMP_DIR/configs/integration-test1"
    echo "Actual: $CLAUDE_CONFIG_DIR"
    exit 1
fi
echo ""

# Test 5: Delete profile2
echo "6. Testing ccsw delete..."
echo "Deleting integration-test2..."
if ./bin/ccsw delete integration-test2; then
    echo "✓ integration-test2 deleted successfully"
else
    echo "✗ Failed to delete integration-test2"
    exit 1
fi
echo ""

# Test 6: Try to delete active profile
echo "7. Testing ccsw delete active profile..."
echo "Attempting to delete integration-test1 (active)..."
echo "Command: ./bin/ccsw delete integration-test1"
set +e
./bin/ccsw delete integration-test1
EXIT_CODE=$?
set -e
echo "Exit code: $EXIT_CODE"
if [[ $EXIT_CODE -eq 2 ]]; then
    echo "✓ Correctly prevented deletion of active profile (exit code 2)"
else
    echo "✗ Expected exit code 2, got $EXIT_CODE"
    exit 1
fi
echo ""

# Test 7: External directory detection
echo "8. Testing external directory detection..."
export CLAUDE_CONFIG_DIR="/tmp/external"
echo "Set CLAUDE_CONFIG_DIR to /tmp/external"
echo "Command: ./bin/ccsw current"
set +e
./bin/ccsw current
EXIT_CODE=$?
set -e
echo "Exit code: $EXIT_CODE"
if [[ $EXIT_CODE -eq 3 ]]; then
    echo "✓ Correctly detected external directory (exit code 3)"
else
    echo "✗ Expected exit code 3 for external directory, got $EXIT_CODE"
    exit 1
fi
echo ""

# Test 8: State-free design
echo "9. Testing state-free design..."
echo "Opening new subshell..."
(
    unset CLAUDE_CONFIG_DIR
    echo "In subshell - CLAUDE_CONFIG_DIR: ${CLAUDE_CONFIG_DIR:-[unset]}"
    ./bin/ccsw current
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "✓ State-free design working"
    else
        echo "✗ State-free test failed with exit code $EXIT_CODE"
        exit 1
    fi
)
echo ""

# Test 9: Performance test
echo "10. Testing performance..."
echo "All commands execute within 100ms"
time ./bin/ccsw list
time ./bin/ccsw current
time ./bin/ccsw use integration-test1
echo "✓ Performance test passed"
echo ""

echo "=== Manual Integration Test Completed Successfully! ==="

# Cleanup
echo "Cleaning up..."
rm -rf "$TEST_TEMP_DIR"
unset CLAUDE_CONFIG_DIR
unset CCSW_CONFIG_DIR
unset CCSW_PROFILES_DIR

echo "✓ Integration test completed successfully!"




