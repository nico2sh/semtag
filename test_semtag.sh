#!/usr/bin/env bash

# Test script for semtag beta/alpha/rc increment functionality
# This script validates that pre-release version increments work correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEMTAG="$SCRIPT_DIR/semtag"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Array to store created tags for cleanup
CREATED_TAGS=()

# Function to print test results
print_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo
}

# Function to create a test tag
create_tag() {
    local tag="$1"
    git tag "$tag" -m "test tag: $tag" >/dev/null 2>&1
    CREATED_TAGS+=("$tag")
}

# Function to delete test tags
cleanup_tags() {
    if [ ${#CREATED_TAGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Cleaning up test tags...${NC}"
        for tag in "${CREATED_TAGS[@]}"; do
            git tag -d "$tag" >/dev/null 2>&1 || true
        done
        CREATED_TAGS=()
    fi
}

# Cleanup on exit
trap cleanup_tags EXIT

echo "================================================"
echo "Semtag Pre-release Version Increment Tests"
echo "================================================"
echo

# Get the current state
INITIAL_LAST=$("$SEMTAG" getlast)
INITIAL_FINAL=$("$SEMTAG" getfinal)
echo "Initial state:"
echo "  Last version:  $INITIAL_LAST"
echo "  Final version: $INITIAL_FINAL"
echo

# Test 1: Beta with patch scope - first beta
echo "=== Test 1: Beta Patch Increment ==="
result=$("$SEMTAG" beta -s patch -o)
print_result "First beta with patch scope" "v0.2.1-beta.1" "$result"

# Test 2: Beta with patch scope - increment beta number
create_tag "v0.2.1-beta.1"
result=$("$SEMTAG" beta -s patch -o)
print_result "Increment beta.1 to beta.2" "v0.2.1-beta.2" "$result"

# Test 3: Beta with patch scope - increment beta number again
create_tag "v0.2.1-beta.2"
result=$("$SEMTAG" beta -s patch -o)
print_result "Increment beta.2 to beta.3" "v0.2.1-beta.3" "$result"

cleanup_tags

# Test 4: Beta with minor scope - first beta
echo "=== Test 2: Beta Minor Increment ==="
result=$("$SEMTAG" beta -s minor -o)
print_result "First beta with minor scope" "v0.3.0-beta.1" "$result"

# Test 5: Beta with minor scope - increment beta number
create_tag "v0.3.0-beta.1"
result=$("$SEMTAG" beta -s minor -o)
print_result "Increment beta.1 to beta.2 (minor)" "v0.3.0-beta.2" "$result"

# Test 6: Beta with minor scope - increment beta number again
create_tag "v0.3.0-beta.2"
result=$("$SEMTAG" beta -s minor -o)
print_result "Increment beta.2 to beta.3 (minor)" "v0.3.0-beta.3" "$result"

cleanup_tags

# Test 7: Beta with major scope - first beta
echo "=== Test 3: Beta Major Increment ==="
result=$("$SEMTAG" beta -s major -o)
print_result "First beta with major scope" "v1.0.0-beta.1" "$result"

# Test 8: Beta with major scope - increment beta number
create_tag "v1.0.0-beta.1"
result=$("$SEMTAG" beta -s major -o)
print_result "Increment beta.1 to beta.2 (major)" "v1.0.0-beta.2" "$result"

cleanup_tags

# Test 9: Alpha increments
echo "=== Test 4: Alpha Increment ==="
result=$("$SEMTAG" alpha -s patch -o)
print_result "First alpha with patch scope" "v0.2.1-alpha.1" "$result"

create_tag "v0.2.1-alpha.1"
result=$("$SEMTAG" alpha -s patch -o)
print_result "Increment alpha.1 to alpha.2" "v0.2.1-alpha.2" "$result"

cleanup_tags

# Test 10: Release candidate increments
echo "=== Test 5: Release Candidate Increment ==="
result=$("$SEMTAG" candidate -s patch -o)
print_result "First rc with patch scope" "v0.2.1-rc.1" "$result"

create_tag "v0.2.1-rc.1"
result=$("$SEMTAG" candidate -s patch -o)
print_result "Increment rc.1 to rc.2" "v0.2.1-rc.2" "$result"

cleanup_tags

# Test 11: Switching between identifiers
echo "=== Test 6: Identifier Switching ==="
create_tag "v0.3.0-alpha.5"
result=$("$SEMTAG" beta -s minor -o)
print_result "Switch from alpha to beta (same version)" "v0.3.0-beta.1" "$result"

create_tag "v0.3.0-beta.1"
result=$("$SEMTAG" alpha -s minor -o)
print_result "Switch from beta to alpha (bumps version)" "v0.4.0-alpha.1" "$result"

cleanup_tags

# Test 12: Multiple sequential increments
echo "=== Test 7: Sequential Beta Increments ==="
create_tag "v0.2.1-beta.1"
create_tag "v0.2.1-beta.2"
create_tag "v0.2.1-beta.3"
result=$("$SEMTAG" beta -s patch -o)
print_result "Increment beta.3 to beta.4" "v0.2.1-beta.4" "$result"

cleanup_tags

# Test 13: Final version with patch scope
echo "=== Test 8: Final Version Patch Increment ==="
# Start from v0.2.0, increment patch
result=$("$SEMTAG" final -s patch -o -f)
print_result "Final version patch increment" "v0.2.1" "$result"

# Test 14: Final version with minor scope
echo "=== Test 9: Final Version Minor Increment ==="
result=$("$SEMTAG" final -s minor -o -f)
print_result "Final version minor increment" "v0.3.0" "$result"

# Test 15: Final version with major scope
echo "=== Test 10: Final Version Major Increment ==="
result=$("$SEMTAG" final -s major -o -f)
print_result "Final version major increment" "v1.0.0" "$result"

# Test 16: Sequential final versions
echo "=== Test 11: Sequential Final Version Increments ==="
create_tag "v0.2.1"
result=$("$SEMTAG" final -s patch -o -f)
print_result "Increment v0.2.1 to v0.2.2" "v0.2.2" "$result"

create_tag "v0.2.2"
result=$("$SEMTAG" final -s patch -o -f)
print_result "Increment v0.2.2 to v0.2.3" "v0.2.3" "$result"

cleanup_tags

# Test 17: Going from pre-release to final
echo "=== Test 12: Pre-release to Final Version ==="
create_tag "v0.3.0-beta.3"
result=$("$SEMTAG" final -s minor -o -f)
print_result "From beta.3 to final minor version" "v0.3.0" "$result"

create_tag "v0.4.0-rc.2"
result=$("$SEMTAG" final -s minor -o -f)
print_result "From rc.2 to final minor version" "v0.4.0" "$result"

cleanup_tags

# Test 18: Mixed major/minor/patch with pre-releases
echo "=== Test 13: Mixed Version Scenarios ==="
create_tag "v1.5.3"
result=$("$SEMTAG" beta -s patch -o)
print_result "From v1.5.3 to beta patch" "v1.5.4-beta.1" "$result"

create_tag "v1.5.4-beta.1"
create_tag "v1.5.4-beta.2"
result=$("$SEMTAG" final -s patch -o -f)
print_result "From beta.2 to final patch" "v1.5.4" "$result"

cleanup_tags

# Test 19: Major version with pre-releases
echo "=== Test 14: Major Version with Pre-releases ==="
create_tag "v2.0.0"
result=$("$SEMTAG" beta -s major -o)
print_result "From v2.0.0 to major beta" "v3.0.0-beta.1" "$result"

create_tag "v3.0.0-beta.1"
result=$("$SEMTAG" final -s major -o -f)
print_result "From beta.1 to final major" "v3.0.0" "$result"

cleanup_tags

# Print summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo -e "Tests run:    $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests failed: $TESTS_FAILED${NC}"
fi
echo "================================================"

# Exit with failure if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
