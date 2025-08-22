#!/usr/bin/env bash
# run-tests.sh - Test suite for tm-monitor

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "TM-Monitor Test Suite"
echo "===================="
echo

# Source libraries for testing
source "$PROJECT_DIR/lib/constants.sh"
source "$PROJECT_DIR/lib/logger.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local name="$1"
    local result
    
    echo -n "Testing $name... "
    ((TESTS_RUN++))
    
    if "$@" >/dev/null 2>&1; then
        echo "✓ PASS"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL"
        ((TESTS_FAILED++))
    fi
}

# Test: Constants loaded
test_constants() {
    [[ -n "$TM_MONITOR_VERSION" ]] && \
    [[ -n "$DEFAULT_INTERVAL" ]] && \
    [[ ${#TABLE_COLUMNS[@]} -gt 0 ]]
}

# Test: Logger functions exist
test_logger() {
    type -t debug >/dev/null && \
    type -t info >/dev/null && \
    type -t error >/dev/null
}

# Test: Calculate minimum width
test_width_calculation() {
    local width
    width=$(calculate_minimum_width)
    [[ "$width" -gt 100 ]] && [[ "$width" -lt 200 ]]
}

# Test: Python helper exists
test_python_helper() {
    [[ -x "$PROJECT_DIR/bin/tm-monitor-helper.py" ]]
}

# Test: Main script exists
test_main_script() {
    [[ -x "$PROJECT_DIR/bin/tm-monitor" ]]
}

# Run tests
run_test "constants loaded" test_constants
run_test "logger functions" test_logger
run_test "width calculation" test_width_calculation
run_test "Python helper exists" test_python_helper
run_test "main script exists" test_main_script

# Summary
echo
echo "Test Results:"
echo "  Tests run: $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"

[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1
