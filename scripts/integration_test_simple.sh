#!/usr/bin/env bash

# Simple integration test that tests each step individually
set -Eeuo pipefail

echo "=== ccsw Integration Test ==="

# Test 1: Create test profiles
echo ""
echo "1. Creating test profiles..."
mkdir -p "$HOME/.config/ccsw/configs/test-profile1"
mkdir -p "$HOME/.config/ccsw/configs/test-profile2"
echo "✓ Created test-profile1 and test-profile2"

# Test 2: List profiles
echo ""
echo "2. Testing ccsw list..."
echo "Running: ./bin/ccsw list"
./bin/ccsw list
echo "✓ Profiles listed successfully"

# Test 3: Use profile1
echo ""
echo "3. Testing ccsw use..."
echo "Setting CLAUDE_CONFIG_DIR to test profile1..."
unset CLAUDE_CONFIG_DIR || true
eval "$(./bin/ccsw use test-profile1)"
echo "CLAUDE_CONFIG_DIR is now: $CLAUDE_CONFIG_DIR"

# Test 4: Check current profile
echo ""
echo "4. Testing ccsw current..."
./bin/ccsw current
echo "✓ Current profile command executed"

# Test 5: Verify CLAUDE_CONFIG_DIR
echo ""
echo "5. Verifying CLAUDE_CONFIG_DIR..."
if [[ "$CLAUDE_CONFIG_DIR" == "$HOME/.config/ccsw/configs/test-profile1" ]]; then
    echo "✓ CLAUDE_CONFIG_DIR is correct"
else
    echo "✗ CLAUDE_CONFIG_DIR is incorrect"
    exit 1
fi

# Test 6: Delete profile2
echo ""
echo "6. Testing ccsw delete..."
echo "Deleting test-profile2..."
if ./bin/ccsw delete test-profile2; then
    echo "✓ test-profile2 deleted successfully"
else
    echo "✗ Failed to delete test-profile2"
    exit 1
fi

# Test 7: Try to delete active profile
echo ""
echo "7. Testing ccsw delete active profile..."
echo "Attempting to delete test-profile1 (active)..."
echo "Command: ./bin/ccsw delete test-profile1"
./bin/ccsw delete test-profile1 || true
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
if [[ $EXIT_CODE -eq 2 ]]; then
    echo "✓ Correctly prevented deletion of active profile (exit code 2)"
else
    echo "✗ Expected exit code 2, got $EXIT_CODE"
    exit 1
fi

# Test 8: External directory detection
echo ""
echo "8. Testing external directory detection..."
export CLAUDE_CONFIG_DIR="/tmp/external"
echo "Set CLAUDE_CONFIG_DIR to /tmp/external"
./bin/ccsw current
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 3 ]]; then
    echo "✓ Correctly detected external directory (exit code 3)"
else
    echo "✗ Expected exit code 3 for external directory, got $EXIT_CODE"
    exit 1
fi

# Test 9: State-free design
echo ""
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
echo "=== All integration tests passed! ==="

# Cleanup
echo "Cleaning up..."
rm -rf "$HOME/.config/ccsw/configs/test-profile1"
rm -rf "$HOME/.config/ccsw/configs/test-profile2" 2>/dev/null || true
unset CLAUDE_CONFIG_DIR

echo "✓ Integration test completed successfully!"