#!/usr/bin/env bats

# ==============================================================================
# BATS TESTS for setups script
# ==============================================================================

# Load the script under test
load ../setups

# Setup and teardown for each test
setup() {
    # Create a temporary directory for test isolation
    export TEST_SETUPS_HOME="$(mktemp -d)"
    export SETUPS_HOME="$TEST_SETUPS_HOME"
    export SETUPS_FORCE=""
    
    # Create required directories
    mkdir -p "$SETUPS_HOME"/{bin,profile.d,preload.d,plugins.d,setups.d}
    
    # Disable debug mode for cleaner test output
    unset DEBUG
}

teardown() {
    # Clean up test directory
    [[ -n "$TEST_SETUPS_HOME" ]] && rm -rf "$TEST_SETUPS_HOME"
}

# ==============================================================================
# UTILITY FUNCTION TESTS
# ==============================================================================

@test "url_path extracts path from URL correctly" {
    run url_path "https://example.com/path/to/file.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "/path/to/file.txt" ]
}

@test "url_path handles URLs with query parameters" {
    run url_path "https://example.com/path/file.txt?param=value"
    [ "$status" -eq 0 ]
    [ "$output" = "/path/file.txt" ]
}

@test "created returns true for existing files" {
    local test_file="$SETUPS_HOME/test_file"
    touch "$test_file"
    
    run created "$test_file"
    [ "$status" -eq 0 ]
}

@test "created returns false for non-existing files" {
    run created "$SETUPS_HOME/non_existing_file"
    [ "$status" -eq 1 ]
}

@test "created respects SETUPS_FORCE flag" {
    local test_file="$SETUPS_HOME/test_file"
    touch "$test_file"
    export SETUPS_FORCE="--force"
    
    run created "$test_file"
    [ "$status" -eq 1 ]
}

@test "creates is an alias for created" {
    local test_file="$SETUPS_HOME/test_file"
    touch "$test_file"
    
    run creates "$test_file"
    [ "$status" -eq 0 ]
}

@test "needs runs setup function for missing command" {
    # Define a mock setup function
    setup_testcommand() {
        echo "setup_testcommand called"
    }
    
    run needs testcommand
    [ "$status" -eq 0 ]
    [[ "$output" == *"setup_testcommand called"* ]]
}

@test "needs skips setup for existing command" {
    # Create a mock command
    local mock_cmd="$SETUPS_HOME/bin/testcommand"
    echo '#!/bin/bash' > "$mock_cmd"
    chmod +x "$mock_cmd"
    export PATH="$SETUPS_HOME/bin:$PATH"
    
    run needs testcommand
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "needs fails for missing setup function" {
    run needs nonexistentcommand
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: No setup function found for 'nonexistentcommand'"* ]]
}

# ==============================================================================
# SOURCE_DIR FUNCTION TESTS
# ==============================================================================

@test "source_dir sources files from directory" {
    # Create a test setup file
    echo 'echo "test setup sourced"' > "$SETUPS_HOME/setups.d/test.sh"

    # Source the directory should not fail
    run source_dir "$SETUPS_HOME/setups.d"
    # env|sort
    [ "$status" -eq 0 ]
    [[ "$output" == *"test setup sourced"* ]]
}

@test "source_dir creates directory if it doesn't exist" {
    local new_dir="$SETUPS_HOME/new_dir"
    
    run source_dir "$new_dir"
    [ "$status" -eq 0 ]
    [ -d "$new_dir" ]
}

@test "source_dir handles empty directory gracefully" {
    local empty_dir="$SETUPS_HOME/empty"
    mkdir -p "$empty_dir"
    
    run source_dir "$empty_dir"
    [ "$status" -eq 0 ]
}

# ==============================================================================
# BUILTIN FUNCTION TESTS
# ==============================================================================

@test "setup_--version outputs version information" {
    run setup_--version
    [ "$status" -eq 0 ]
    
    # Test that output contains version-like format (X.Y.Z-name)
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z]+ ]]
    
    # Test that output contains checksum
    [[ "$output" == *"checksum (SHA256):"* ]]
    
    # Test that it's not empty or just whitespace
    [[ -n "$(echo "$output" | tr -d '[:space:]')" ]]
}

@test "setup_--version format matches expected pattern" {
    run setup_--version
    [ "$status" -eq 0 ]
    
    # Extract just the version line (first line)
    local version_line="$(echo "$output" | head -n1)"
    
    # Should match pattern: number.number.number-word
    [[ "$version_line" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z]+$ ]]
}

@test "_setup_flags lists builtin flags" {
    run _setup_flags
    [ "$status" -eq 0 ]
    [[ "$output" == *"--help"* ]]
    [[ "$output" == *"--version"* ]]
    [[ "$output" == *"--list"* ]]
}

@test "setup_--list shows available setup functions" {
    # Create a test setup function
    setup_example() {
        echo "example setup"
    }
    
    run setup_--list
    [ "$status" -eq 0 ]
    [[ "$output" == *"example"* ]]
}

@test "setup_--force sets SETUPS_FORCE flag" {
    # Execute the function directly (not in a subshell)
    setup_--force
    [ "$SETUPS_FORCE" = "--force" ]
}

@test "setup_--help displays usage information" {
    SETUPS_BUILTINS="--help --version --list"
    SETUPS_SOURCE="test"
    
    run setup_--help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: setups [options] name [name ...]"* ]]
    [[ "$output" == *"Built-in options:"* ]]
    [[ "$output" == *"Environment: SETUPS_HOME=$SETUPS_HOME"* ]]
}

@test "setup_--readme displays documentation" {
    run setup_--readme
    [ "$status" -eq 0 ]
    [[ "$output" == *"Setups is a simple bash utility"* ]]
    [[ "$output" == *"setup_brew"* ]]
}

# ==============================================================================
# MAIN SETUPS FUNCTION TESTS
# ==============================================================================

@test "setups runs existing setup function" {
    # Define a test setup function
    setup_example() {
        echo "example setup executed"
    }
    
    run setups example
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running setups for example"* ]]
    [[ "$output" == *"example setup executed"* ]]
}

@test "setups fails for non-existing setup function" {
    run setups nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: No setup function found for 'nonexistent'"* ]]
    [[ "$output" == *"Run 'setups --list' to see available setups"* ]]
}

@test "setups processes builtin options" {
    SETUPS_BUILTINS="--help --version"
    
    run setups --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"dumbledore"* ]]
}

@test "setups fails for unknown options" {
    run setups --unknown
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Unknown option '--unknown'"* ]]
    [[ "$output" == *"Run 'setups --help' for available options"* ]]
}

@test "setups handles double dash separator" {
    setup_test() {
        echo "test with args: $*"
    }
    
    run setups test -- --not-an-option
    [ "$status" -eq 0 ]
    [[ "$output" == *"test with args:"* ]]
}

# ==============================================================================
# INTEGRATION TESTS
# ==============================================================================

@test "setups_prepare creates required directories" {
    # Remove directories first
    rm -rf "$SETUPS_HOME"/{bin,profile.d}
    
    # Mock the _setup_flags function to avoid infinite recursion
    _setup_flags() {
        echo "--help --version"
    }
    
    # Mock setups function to avoid infinite recursion
    setups() {
        echo "setups called with: $*"
    }
    
    run setups_prepare
    [ "$status" -eq 0 ]
    [ -d "$SETUPS_HOME/bin" ]
    [ -d "$SETUPS_HOME/profile.d" ]
}

@test "script sources correctly when executed" {
    # Create a minimal test script that sources setups
    cat > "$SETUPS_HOME/test_source.sh" << 'EOF'
#!/usr/bin/env bash
source ../setups
echo "SETUPS_HOME: $SETUPS_HOME"
EOF
    chmod +x "$SETUPS_HOME/test_source.sh"
    
    cd "$SETUPS_HOME"
    run ./test_source.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"SETUPS_HOME:"* ]]
}

# ==============================================================================
# ERROR HANDLING TESTS
# ==============================================================================

@test "script handles missing directories gracefully" {
    # Test with a non-existent base directory
    export SETUPS_HOME="/tmp/non_existent_$(date +%s)"
    
    run source_dir "$SETUPS_HOME/setups.d"
    [ "$status" -eq 0 ]
    [ -d "$SETUPS_HOME/setups.d" ]
    
    # Cleanup
    rm -rf "$SETUPS_HOME"
}

@test "script handles unreadable files gracefully" {
    # Create an unreadable file
    local unreadable_file="$SETUPS_HOME/setups.d/unreadable.sh"
    echo "echo 'should not be sourced'" > "$unreadable_file"
    chmod 000 "$unreadable_file"
    
    run source_dir "$SETUPS_HOME/setups.d"
    [ "$status" -eq 0 ]
    
    # Cleanup
    chmod 644 "$unreadable_file"
}

# ==============================================================================
# ENVIRONMENT VARIABLE TESTS
# ==============================================================================

@test "SETUPS_HOME defaults to \$HOME/setups" {
    # Test in a completely clean environment without SETUPS_HOME
    run bash -c 'unset SETUPS_HOME; source ../setups; echo "$SETUPS_HOME"'
    [ "$status" -eq 0 ]
    
    # Should be exactly $HOME/setups
    local expected_path="$HOME/setups"
    [ "$output" = "$expected_path" ]
}

@test "SETUPS_HOME respects existing environment variable" {
    local custom_home="/tmp/custom_setups_$(date +%s)"
    run bash -c "export SETUPS_HOME='$custom_home'; source ../setups; echo \"\$SETUPS_HOME\""
    [ "$status" -eq 0 ]
    [ "$output" = "$custom_home" ]
}

@test "DEBUG mode enables set -x" {
    export DEBUG=1
    setup_test() {
        echo "test function"
    }
    
    run setups test
    [ "$status" -eq 0 ]
    # When DEBUG is set, bash outputs trace information with +
    [[ "$output" == *"+"* ]]
}