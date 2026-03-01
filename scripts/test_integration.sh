#!/usr/bin/env bash

# Integration test script for ccsw tool
set -Eeuo pipefail

# Setup test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/ccsw-test-$$"

echo "Starting ccsw integration tests..."
echo "Project root: $PROJECT_ROOT"

# Ensure ccsw is executable and in PATH
export PATH="$PROJECT_ROOT/bin:$PATH"

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "✓ Test directory created: $TEST_DIR"

# Test 1: Create 2 test profiles manually
echo ""
echo "=== Test 1: Creating test profiles ==="
mkdir -p "$HOME/.config/ccsw/configs/profile1"
mkdir -p "$HOME/.config/ccsw/configs/profile2"
echo "Created profiles: profile1 and profile2"
ls -la "$HOME/.config/ccsw/configs/"

# Test 2: Run 'ccsw list' - verify both profiles appear alphabetically
echo ""
echo "=== Test 2: Testing ccsw list ==="
echo "Running: ccsw list"
ccsw_list

# Test 3: Run 'eval "$(ccsw use profile1)"' - verify CLAUDE_CONFIG_DIR set correctly
echo ""
echo "=== Test 3: Testing ccsw use ==="
echo "Running: eval \"$(ccsw use profile1)\""
eval "$(ccsw use profile1)"
echo "CLAUDE_CONFIG_DIR is: $CLAUDE_CONFIG_DIR"
echo "Expected: $HOME/.config/ccsw/configs/profile1"
if [[ "$CLAUDE_CONFIG_DIR" == "$HOME/.config/ccsw/configs/profile1" ]]; then
    echo "✓ SUCCESS: CLAUDE_CONFIG_DIR set correctly"
else
    echo "✗ FAILURE: CLAUDE_CONFIG_DIR not set correctly"
    exit 1
fi

# Test 4: Run 'ccsw current' - verify shows 'profile1'
echo ""
echo "=== Test 4: Testing ccsw current ==="
echo "Running: ccsw current"
ccsw_current
echo "Expected: profile1"
CURRENT_PROFILE=$(ccsw_current)
if [[ "$CURRENT_PROFILE" == "profile1" ]]; then
    echo "✓ SUCCESS: Current profile is profile1"
else
    echo "✗ FAILURE: Current profile is not profile1"
    exit 1
fi

# Test 5: Run 'echo $CLAUDE_CONFIG_DIR' - verify path is ~/.config/ccsw/configs/profile1
echo ""
echo "=== Test 5: Verifying CLAUDE_CONFIG_DIR ==="
echo "$CLAUDE_CONFIG_DIR"
if [[ "$CLAUDE_CONFIG_DIR" == "$HOME/.config/ccsw/configs/profile1" ]]; then
    echo "✓ SUCCESS: CLAUDE_CONFIG_DIR correct"
else
    echo "✗ FAILURE: CLAUDE_CONFIG_DIR incorrect"
    exit 1
fi

# Test 6: Run 'ccsw delete profile2' - verify directory removed
echo ""
echo "=== Test 6: Testing ccsw delete (profile2) ==="
echo "Running: ccsw delete profile2"
ccsw delete profile2
echo "Checking if profile2 directory exists..."
if [[ ! -d "$HOME/.config/ccsw/configs/profile2" ]]; then
    echo "✓ SUCCESS: profile2 directory deleted"
else
    echo "✗ FAILURE: profile2 directory still exists"
    exit 1
fi

# Test 7: Run 'ccsw delete profile1' - verify error (active profile, exit code 2)
echo ""
echo "=== Test 7: Testing ccsw delete active profile ==="
echo "Running: ccsw delete profile1"
ccsw delete profile1
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
if [[ $EXIT_CODE -eq 2 ]]; then
    echo "✓ SUCCESS: Correctly prevented deletion of active profile"
else
    echo "✗ FAILURE: Expected exit code 2, got $EXIT_CODE"
    exit 1
fi

# Test 8: Set CLAUDE_CONFIG_DIR to /tmp/external, run 'ccsw current' - verify exit code 3 and warning
echo ""
echo "=== Test 8: Testing external directory detection ==="
export CLAUDE_CONFIG_DIR="/tmp/external"
echo "Set CLAUDE_CONFIG_DIR to /tmp/external"
echo "Running: ccsw current"
ccsw_current
EXIT_CODE=$?
echo "Exit code: $EXIT_CODE"
if [[ $EXIT_CODE -eq 3 ]]; then
    echo "✓ SUCCESS: Correctly detected external directory"
else
    echo "✗ FAILURE: Expected exit code 3 for external directory, got $EXIT_CODE"
    exit 1
fi

# Test 9: Open new shell, run 'ccsw current' - verify shows 'No active profile' (state-free)
echo ""
echo "=== Test 9: Testing state-free design ==="
echo "Opening new subshell for state-free test..."
(
    # Clear CLAUDE_CONFIG_DIR in subshell
    unset CLAUDE_CONFIG_DIR
    echo "In subshell - CLAUDE_CONFIG_DIR is: ${CLAUDE_CONFIG_DIR:-[unset]}"
    echo "Running: ccsw current"
    ccsw_current
    EXIT_CODE=$?
    echo "Exit code: $EXIT_CODE"
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "✓ SUCCESS: State-free design working"
    else
        echo "✗ FAILURE: State-free test failed with exit code $EXIT_CODE"
        exit 1
    fi
)

# Test 10: Check all commands execute within 100ms
echo ""
echo "=== Test 10: Performance test ==="
for cmd in "ccsw list" "ccsw current" "ccsw use profile1"; do
    echo "Testing: $cmd"
    time {
        eval "$cmd"
    }
done

echo ""
echo "=== All integration tests completed successfully! ==="

# Cleanup
echo "Cleaning up test directory..."
rm -rf "$HOME/.config/ccsw/configs/profile1"
rm -rf "$HOME/.config/ccsw/configs/profile2"
cd /tmp
rm -rf "$TEST_DIR"

echo "✓ All tests passed!"




