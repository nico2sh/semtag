#!/usr/bin/env bash

# release.sh - Release automation script (Refactored)
# Improved version with better error handling, validation, and maintainability

set -euo pipefail  # Fail fast on errors, undefined variables, and pipe failures

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SEMTAG_SCRIPT="${SCRIPT_DIR}/semtag"
readonly README_FILE="${SCRIPT_DIR}/README.md"

# Configuration with defaults
declare -A CONFIG=(
    [scope]="${1:-auto}"
    [dry_run]="false"
    [verbose]="false"
)

# Utility functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

verbose() {
    [[ "${CONFIG[verbose]}" == "true" ]] && log "$*"
}

# Validate dependencies
check_dependencies() {
    if [[ ! -f "$SEMTAG_SCRIPT" ]]; then
        error "semtag script not found at: $SEMTAG_SCRIPT"
    fi

    if [[ ! -x "$SEMTAG_SCRIPT" ]]; then
        log "Making semtag executable..."
        chmod +x "$SEMTAG_SCRIPT"
    fi

    if [[ ! -f "$README_FILE" ]]; then
        error "README.md not found at: $README_FILE"
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not in a git repository"
    fi

    # Check for uncommitted changes (unless dry run)
    if [[ "${CONFIG[dry_run]}" == "false" ]]; then
        if ! git diff --quiet HEAD 2>/dev/null; then
            error "Repository has uncommitted changes. Commit or stash them first."
        fi
    fi
}

# Validate scope parameter
validate_scope() {
    local scope="${CONFIG[scope]}"
    case "$scope" in
        auto|major|minor|patch)
            verbose "Using scope: $scope"
            ;;
        *)
            error "Invalid scope '$scope'. Must be one of: auto, major, minor, patch"
            ;;
    esac
}

# Get next version without tagging
get_next_version() {
    local version
    verbose "Getting next version with scope '${CONFIG[scope]}'..."

    # Use the semtag script to get next version (dry run mode)
    if ! version=$("$SEMTAG_SCRIPT" final -o -s "${CONFIG[scope]}" 2>/dev/null); then
        error "Failed to get next version from semtag"
    fi

    if [[ -z "$version" ]]; then
        error "semtag returned empty version"
    fi

    verbose "Next version will be: $version"
    echo "$version"
}

# Update version in files
update_version_in_files() {
    local version="$1"

    log "Updating version to $version in source files..."

    # Create backup function for safer file operations
    backup_file() {
        local file="$1"
        if [[ -f "$file" ]]; then
            cp "$file" "${file}.backup"
            verbose "Created backup: ${file}.backup"
        fi
    }

    # Restore backup function
    restore_backup() {
        local file="$1"
        if [[ -f "${file}.backup" ]]; then
            mv "${file}.backup" "$file"
            log "Restored backup for $file"
        fi
    }

    # Clean backup function
    cleanup_backup() {
        local file="$1"
        if [[ -f "${file}.backup" ]]; then
            rm "${file}.backup"
            verbose "Cleaned up backup: ${file}.backup"
        fi
    }

    # Trap to cleanup backups on error
    trap 'restore_backup "$SEMTAG_SCRIPT"; restore_backup "$README_FILE"' ERR

    # Update semtag script version
    backup_file "$SEMTAG_SCRIPT"

    if ! sed -i '' "s/^PROG_VERSION=\"[^\"]*\"/PROG_VERSION=\"$version\"/g" "$SEMTAG_SCRIPT"; then
        error "Failed to update version in $SEMTAG_SCRIPT"
    fi
    verbose "Updated version in semtag script"

    # Update README.md version
    backup_file "$README_FILE"

    if ! sed -i '' "s/^\[Version: [^]]*\]/[Version: $version]/g" "$README_FILE"; then
        error "Failed to update version in $README_FILE"
    fi
    verbose "Updated version in README.md"

    # Verify changes were made
    if ! grep -q "PROG_VERSION=\"$version\"" "$SEMTAG_SCRIPT"; then
        error "Version update verification failed for $SEMTAG_SCRIPT"
    fi

    if ! grep -q "\\[Version: $version\\]" "$README_FILE"; then
        error "Version update verification failed for $README_FILE"
    fi

    # Clean up backups on success
    cleanup_backup "$SEMTAG_SCRIPT"
    cleanup_backup "$README_FILE"

    # Disable trap
    trap - ERR

    log "Successfully updated version in all files"
}

# Commit and push changes
commit_and_push_changes() {
    local version="$1"

    log "Committing changes for version $version..."

    # Stage the modified files
    if ! git add "$SEMTAG_SCRIPT" "$README_FILE"; then
        error "Failed to stage modified files"
    fi

    # Commit with descriptive message
    local commit_message="Update version info to $version

- Updated PROG_VERSION in semtag script
- Updated version badge in README.md

Automated release preparation commit."

    if ! git commit -m "$commit_message"; then
        error "Failed to commit changes"
    fi

    verbose "Changes committed successfully"

    # Push changes
    log "Pushing changes to remote..."
    if ! git push; then
        error "Failed to push changes to remote"
    fi

    log "Changes pushed successfully"
}

# Create final tag
create_final_tag() {
    local version="$1"

    log "Creating final tag for version $version..."

    # Use semtag to create the final tag
    if ! "$SEMTAG_SCRIPT" final -f -v "$version"; then
        error "Failed to create final tag with semtag"
    fi

    log "Successfully created and pushed tag: $version"
}

# Show release summary
show_summary() {
    local version="$1"

    log "Release Summary:"
    log "  Version: $version"
    log "  Scope: ${CONFIG[scope]}"
    log "  Files updated: semtag, README.md"
    log "  Git tag created and pushed: $version"
    log ""
    log "Release completed successfully!"
}

# Dry run mode
perform_dry_run() {
    local version
    version=$(get_next_version)

    log "DRY RUN MODE - No changes will be made"
    log "Would release version: $version"
    log "Would update files: $SEMTAG_SCRIPT, $README_FILE"
    log "Would commit and push changes"
    log "Would create and push git tag: $version"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                CONFIG[dry_run]="true"
                shift
                ;;
            --verbose|-v)
                CONFIG[verbose]="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                # Assume it's a scope parameter
                CONFIG[scope]="$1"
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Usage: $(basename "$0") [SCOPE] [OPTIONS]

Release automation script for semtag.

Arguments:
  SCOPE           Version scope to bump (auto|major|minor|patch) [default: auto]

Options:
  --dry-run       Show what would be done without making changes
  --verbose, -v   Enable verbose output
  --help, -h      Show this help message

Examples:
  $(basename "$0")                    # Auto-detect scope and release
  $(basename "$0") minor             # Release with minor version bump
  $(basename "$0") --dry-run         # Preview release actions
  $(basename "$0") patch --verbose   # Release patch with verbose output

This script will:
1. Get the next version using semtag
2. Update version strings in semtag and README.md
3. Commit and push the changes
4. Create and push a git tag using semtag
EOF
}

# Main execution function
main() {
    # Parse arguments (excluding the scope which is handled in CONFIG initialization)
    shift 2>/dev/null || true  # Remove scope from $@ if present
    parse_arguments "$@"

    log "Starting release process with scope: ${CONFIG[scope]}"

    # Validate everything first
    check_dependencies
    validate_scope

    # Handle dry run
    if [[ "${CONFIG[dry_run]}" == "true" ]]; then
        perform_dry_run
        return 0
    fi

    # Execute release process
    local version
    version=$(get_next_version)

    update_version_in_files "$version"
    commit_and_push_changes "$version"
    create_final_tag "$version"
    show_summary "$version"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi