#!/bin/bash

# Script to keep only +ox subdirectories when they exist in a package directory
# Usage: ./filter_ox_dirs.sh [OPTIONS] [DIRECTORY]

set -euo pipefail

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [DIRECTORY]

This script processes package directories and keeps only subdirectories containing '+ox'
when such subdirectories exist. If no '+ox' subdirectories are found, all subdirectories are kept.

Options:
  -n, --dry-run    Show what would be removed without actually removing
  -y, --yes        Skip confirmation prompt (use with caution)
  -h, --help       Show this help message

Arguments:
  DIRECTORY        Target directory to process (default: current directory)

Examples:
  $0                           # Process current directory with confirmation
  $0 -n /path/to/packages      # Dry run on specific directory
  $0 -y -n .                   # Dry run without confirmation prompt
EOF
}

# Default values
DRY_RUN=false
SKIP_CONFIRMATION=false
TARGET_DIR="."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            usage
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist" >&2
    exit 1
fi

# Convert to absolute path for clarity
TARGET_DIR=$(realpath "$TARGET_DIR")

echo "Target directory: $TARGET_DIR"
if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN MODE - No files will actually be removed"
fi
echo

# First pass: analyze what would be changed
packages_to_modify=()
total_dirs_to_remove=0

for package_dir in "$TARGET_DIR"/*; do
    # Skip if not a directory
    [[ ! -d "$package_dir" ]] && continue
    
    package_name=$(basename "$package_dir")
    
    # Find subdirectories containing +ox
    ox_dirs=()
    other_dirs=()
    
    for subdir in "$package_dir"/*; do
        [[ ! -d "$subdir" ]] && continue
        subdir_name=$(basename "$subdir")
        
        if [[ "$subdir_name" == *"+ox" ]]; then
            ox_dirs+=("$subdir_name")
        else
            other_dirs+=("$subdir_name")
        fi
    done
    
    # If we have +ox directories and other directories, this package will be modified
    if [[ ${#ox_dirs[@]} -gt 0 && ${#other_dirs[@]} -gt 0 ]]; then
        packages_to_modify+=("$package_name")
        total_dirs_to_remove=$((total_dirs_to_remove + ${#other_dirs[@]}))
        
        echo "Package: $package_name"
        echo "  Will keep (+ox): ${ox_dirs[*]}"
        echo "  Will remove: ${other_dirs[*]}"
        echo
    fi
done

# Summary
if [[ ${#packages_to_modify[@]} -eq 0 ]]; then
    echo "No packages contain +ox subdirectories that require filtering."
    echo "All directory structures will remain unchanged."
    exit 0
fi

echo "Summary:"
echo "  Packages to modify: ${#packages_to_modify[@]}"
echo "  Total directories to remove: $total_dirs_to_remove"
echo

# Confirmation (unless in dry-run mode or skip confirmation is set)
if [[ "$DRY_RUN" == false && "$SKIP_CONFIRMATION" == false ]]; then
    echo "This will permanently remove $total_dirs_to_remove directories."
    read -p "Do you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
    echo
fi

# Second pass: perform the actual removal
for package_dir in "$TARGET_DIR"/*; do
    # Skip if not a directory
    [[ ! -d "$package_dir" ]] && continue
    
    package_name=$(basename "$package_dir")
    
    # Find subdirectories containing +ox
    ox_dirs=()
    dirs_to_remove=()
    
    for subdir in "$package_dir"/*; do
        [[ ! -d "$subdir" ]] && continue
        subdir_name=$(basename "$subdir")
        
        if [[ "$subdir_name" == *"+ox" ]]; then
            ox_dirs+=("$subdir")
        else
            dirs_to_remove+=("$subdir")
        fi
    done
    
    # If we have +ox directories, remove all others
    if [[ ${#ox_dirs[@]} -gt 0 && ${#dirs_to_remove[@]} -gt 0 ]]; then
        echo "Processing package: $package_name"
        
        for dir_to_remove in "${dirs_to_remove[@]}"; do
            dir_name=$(basename "$dir_to_remove")
            echo "  Removing: $dir_name"
            
            if [[ "$DRY_RUN" == false ]]; then
                rm -rf "$dir_to_remove"
            fi
        done
        echo
    fi
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete! Use without -n flag to perform actual removal."
else
    echo "Processing complete! $total_dirs_to_remove directories removed."
fi
