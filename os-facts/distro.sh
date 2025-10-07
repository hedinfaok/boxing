#!/bin/sh

# ==============================================================================
# POSIX-Portable Distribution Detection Script (distro.sh)
# ==============================================================================
# 
# POSIX-compliant version of distro.py that works with minimal shells
# Detects Linux distribution ID, name, version, codename, and other attributes
# Compatible with BusyBox, dash, ash, and other minimal POSIX shells
#
# USAGE:
#   ./distro.sh [COMMAND] [OPTIONS]
#
# COMMANDS:
#   id         Show distribution ID
#   name       Show distribution name  
#   version    Show distribution version
#   codename   Show distribution codename
#   like       Show distributions this is like (ID_LIKE)
#   info       Show all distribution information
#   help       Show usage information
#
# OPTIONS:
#   --pretty   Include version and codename in name output
#   --best     Use best available version (highest precision)
#   --json     Output in JSON format (for info command)
#
# EXAMPLES:
#   ./distro-portable.sh id                    # Show distribution ID
#   ./distro-portable.sh name --pretty         # Show pretty name with version
#   ./distro-portable.sh version --best        # Show best available version
#   ./distro-portable.sh info --json           # Show all info in JSON format
#
# EXIT CODES:
#   0: Detection successful
#   1: Error occurred
# ==============================================================================

# Configuration constants
UNIXCONFDIR="${UNIXCONFDIR:-/etc}"
UNIXUSRLIBDIR="${UNIXUSRLIBDIR:-/usr/lib}"
OS_RELEASE_BASENAME="os-release"

# Global variables for caching
_os_release_parsed=""
_lsb_release_parsed=""
_distro_release_parsed=""
_uname_parsed=""

# Store parsed values (simulating associative arrays with variables)
_os_id=""
_os_name=""
_os_version_id=""
_os_version=""
_os_pretty_name=""
_os_version_codename=""
_os_ubuntu_codename=""
_os_id_like=""

_lsb_distributor_id=""
_lsb_description=""
_lsb_release=""
_lsb_codename=""

_distro_id=""
_distro_name=""
_distro_version=""
_distro_codename=""

_uname_system=""
_uname_release=""
_uname_machine=""

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Safe file reading
read_file_safe() {
    if [ -r "$1" ]; then
        cat "$1" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Extract value from shell-style assignment (key=value or key="value")
extract_value() {
    local line="$1"
    local value
    
    # Remove everything up to and including the first =
    value="${line#*=}"
    
    # Remove surrounding quotes if present
    case "$value" in
        \"*\") value="${value#\"}" ; value="${value%\"}" ;;
        \'*\') value="${value#\'}" ; value="${value%\'}" ;;
    esac
    
    echo "$value"
}

# Extract key from shell-style assignment
extract_key() {
    local line="$1"
    echo "${line%%=*}"
}

# Convert to lowercase (POSIX-compatible)
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Count dots in version string
count_dots() {
    local str="$1"
    local count=0
    local remaining="$str"
    
    while [ "$remaining" != "${remaining#*.}" ]; do
        count=$((count + 1))
        remaining="${remaining#*.}"
    done
    
    echo "$count"
}

# Extract version from string using basic pattern matching
extract_version() {
    local str="$1"
    local version=""
    
    # Look for patterns like "1.2.3" or "20.04"
    case "$str" in
        *[0-9].[0-9]*) 
            # Extract the version portion
            for word in $str; do
                case "$word" in
                    [0-9]*.[0-9]*) version="$word"; break ;;
                esac
            done
            ;;
    esac
    
    echo "$version"
}

# Extract codename from parentheses
extract_codename_from_parens() {
    local str="$1"
    local result=""
    
    # Simple extraction of text within parentheses
    case "$str" in
        *\(*\)*)
            result="${str#*\(}"
            result="${result%%\)*}"
            ;;
    esac
    
    echo "$result"
}

# Normalize ID value
normalize_id() {
    local id="$1"
    
    # Convert to lowercase and replace spaces with underscores
    id=$(to_lower "$id" | tr ' ' '_')
    
    # Apply specific normalizations
    case "$id" in
        ol) echo "oracle" ;;
        opensuse-leap) echo "opensuse" ;;
        enterpriseenterpriseas) echo "oracle" ;;
        enterpriseenterpriseserver) echo "oracle" ;;
        *) echo "$id" ;;
    esac
}

# ==============================================================================
# OS-RELEASE FILE PARSING
# ==============================================================================

# Parse os-release file
parse_os_release() {
    local file_path="$1"
    local line key value
    
    [ "$_os_release_parsed" = "1" ] && return 0
    
    if [ ! -r "$file_path" ]; then
        _os_release_parsed="1"
        return 1
    fi
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        case "$line" in
            \#*) continue ;;
            "") continue ;;
            *=*) ;;
            *) continue ;;
        esac
        
        key=$(extract_key "$line")
        value=$(extract_value "$line")
        
        # Convert key to lowercase and store in variables
        case "$(to_lower "$key")" in
            id) _os_id="$value" ;;
            name) _os_name="$value" ;;
            version_id) _os_version_id="$value" ;;
            version) _os_version="$value" ;;
            pretty_name) _os_pretty_name="$value" ;;
            version_codename) _os_version_codename="$value" ;;
            ubuntu_codename) _os_ubuntu_codename="$value" ;;
            id_like) _os_id_like="$value" ;;
        esac
    done < "$file_path"
    
    # Extract codename from version if not already set
    if [ -z "$_os_version_codename" ] && [ -n "$_os_version" ]; then
        _os_version_codename=$(extract_codename_from_parens "$_os_version")
    fi
    
    _os_release_parsed="1"
    return 0
}

# Load os-release information
load_os_release_info() {
    [ "$_os_release_parsed" = "1" ] && return 0
    
    local etc_file="$UNIXCONFDIR/$OS_RELEASE_BASENAME"
    local usr_lib_file="$UNIXUSRLIBDIR/$OS_RELEASE_BASENAME"
    
    if [ -f "$etc_file" ]; then
        parse_os_release "$etc_file"
    elif [ -f "$usr_lib_file" ]; then
        parse_os_release "$usr_lib_file"
    else
        _os_release_parsed="1"
    fi
}

# ==============================================================================
# LSB RELEASE COMMAND PARSING
# ==============================================================================

# Parse lsb_release command output
parse_lsb_release() {
    local line key value
    
    [ "$_lsb_release_parsed" = "1" ] && return 0
    
    if ! command_exists lsb_release; then
        _lsb_release_parsed="1"
        return 1
    fi
    
    lsb_release -a 2>/dev/null | while IFS=: read -r key value; do
        # Remove leading/trailing whitespace from value
        value="${value# }"
        value="${value% }"
        
        case "$(to_lower "$key" | tr ' ' '_')" in
            distributor_id) _lsb_distributor_id="$value" ;;
            description) _lsb_description="$value" ;;
            release) _lsb_release="$value" ;;
            codename) _lsb_codename="$value" ;;
        esac
    done
    
    _lsb_release_parsed="1"
}

# Load lsb_release information
load_lsb_release_info() {
    [ "$_lsb_release_parsed" = "1" ] && return 0
    parse_lsb_release
}

# ==============================================================================
# DISTRO RELEASE FILE PARSING
# ==============================================================================

# Find distro release file
find_distro_release_file() {
    local file
    
    # Known release files in priority order
    for basename in "SuSE-release" "altlinux-release" "arch-release" "base-release" \
                   "centos-release" "fedora-release" "gentoo-release" "mageia-release" \
                   "mandrake-release" "mandriva-release" "mandrivalinux-release" \
                   "manjaro-release" "oracle-release" "redhat-release" "rocky-release" \
                   "sl-release" "slackware-version"; do
        file="$UNIXCONFDIR/$basename"
        if [ -f "$file" ]; then
            echo "$file"
            return 0
        fi
    done
    
    # Scan for other *-release files, excluding ignored ones
    for file in "$UNIXCONFDIR"/*-release; do
        [ -f "$file" ] || continue
        
        case "$(basename "$file")" in
            debian_version|lsb-release|oem-release|os-release|system-release|plesk-release|iredmail-release|board-release|ec2_version)
                continue ;;
            *)
                echo "$file"
                return 0
                ;;
        esac
    done
    
    return 1
}

# Parse distro release file
parse_distro_release_file() {
    local file_path="$1"
    local basename first_line
    
    [ "$_distro_release_parsed" = "1" ] && return 0
    
    if [ ! -r "$file_path" ]; then
        _distro_release_parsed="1"
        return 1
    fi
    
    basename=$(basename "$file_path")
    
    # Extract ID from filename
    case "$basename" in
        *-release) _distro_id="${basename%-release}" ;;
        *-version) _distro_id="${basename%-version}" ;;
    esac
    
    # Read first line for name and version info
    first_line=$(head -n1 "$file_path" 2>/dev/null || echo "")
    
    if [ -n "$first_line" ]; then
        _distro_name="$first_line"
        _distro_version=$(extract_version "$first_line")
        _distro_codename=$(extract_codename_from_parens "$first_line")
    fi
    
    _distro_release_parsed="1"
}

# Load distro release file information
load_distro_release_info() {
    local distro_file
    
    [ "$_distro_release_parsed" = "1" ] && return 0
    
    distro_file=$(find_distro_release_file || echo "")
    
    if [ -n "$distro_file" ]; then
        parse_distro_release_file "$distro_file"
    else
        _distro_release_parsed="1"
    fi
}

# ==============================================================================
# UNAME INFORMATION
# ==============================================================================

# Load uname information
load_uname_info() {
    [ "$_uname_parsed" = "1" ] && return 0
    
    _uname_system=$(uname -s 2>/dev/null || echo "")
    _uname_release=$(uname -r 2>/dev/null || echo "")
    _uname_machine=$(uname -m 2>/dev/null || echo "")
    
    _uname_parsed="1"
}

# ==============================================================================
# MACOS CODENAME DETECTION
# ==============================================================================

# Get macOS codename
get_macos_codename() {
    local version
    
    if command_exists sw_vers; then
        version=$(sw_vers -productVersion 2>/dev/null)
        if [ -n "$version" ]; then
            case "$version" in
                10.12) echo "Sierra" ;;
                10.13) echo "High Sierra" ;;
                10.14) echo "Mojave" ;;
                10.15) echo "Catalina" ;;
                11.*) echo "Big Sur" ;;
                12.*) echo "Monterey" ;;
                13.*) echo "Ventura" ;;
                14.*) echo "Sonoma" ;;
                15.*) echo "Sequoia" ;;
                26.*) echo "Tahoe" ;;
                *)
                    # Fallback: try to extract codename from license files
                    local codename_from_license=""
                    
                    # Try Software License Agreement
                    if [ -f "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf" ]; then
                        codename_from_license=$(grep -i "software license agreement" "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf" 2>/dev/null | head -1 | sed 's/.*macOS \([A-Za-z]*\).*/\1/' | tr '[:lower:]' '[:upper:]' | head -c1)$(grep -i "software license agreement" "/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf" 2>/dev/null | head -1 | sed 's/.*macOS \([A-Za-z]*\).*/\1/' | tr '[:upper:]' '[:lower:]' | cut -c2-)
                    fi
                    if [ -n "$codename_from_license" ]; then
                        echo "$codename_from_license"
                    else
                        echo "unknown"
                    fi
                    ;;
            esac
        fi
    fi
}

# ==============================================================================
# INFORMATION ACCESSOR FUNCTIONS
# ==============================================================================

# Get distribution ID
get_distro_id() {
    local id=""
    
    load_os_release_info
    load_lsb_release_info
    load_distro_release_info
    load_uname_info
    
    if [ -n "$_os_id" ]; then
        id=$(normalize_id "$_os_id")
    elif [ -n "$_lsb_distributor_id" ]; then
        id=$(normalize_id "$_lsb_distributor_id")
    elif [ -n "$_distro_id" ]; then
        id=$(normalize_id "$_distro_id")
    else
        # Fallback to uname for non-Linux systems
        case "$_uname_system" in
            Darwin) id="darwin" ;;
            FreeBSD) id="freebsd" ;;
            OpenBSD) id="openbsd" ;;
            NetBSD) id="netbsd" ;;
            DragonFly) id="dragonfly" ;;
            SunOS) id="solaris" ;;
            AIX) id="aix" ;;
            Linux)
                # Check for BusyBox
                if command_exists busybox; then
                    id="busybox"
                else
                    id="linux"
                fi
                ;;
        esac
    fi
    
    echo "$id"
}

# Get distribution name
get_distro_name() {
    local pretty="${1:-false}"
    local name=""
    
    load_os_release_info
    load_lsb_release_info
    load_distro_release_info
    load_uname_info
    
    if [ "$pretty" = "true" ] && [ -n "$_os_pretty_name" ]; then
        name="$_os_pretty_name"
    elif [ -n "$_os_name" ]; then
        name="$_os_name"
    elif [ -n "$_lsb_description" ]; then
        name="$_lsb_description"
    elif [ -n "$_distro_name" ]; then
        name="$_distro_name"
    else
        case "$_uname_system" in
            Darwin) name="Darwin" ;;
            FreeBSD) name="FreeBSD" ;;
            OpenBSD) name="OpenBSD" ;;
            NetBSD) name="NetBSD" ;;
            DragonFly) name="DragonFly BSD" ;;
            SunOS) name="Solaris" ;;
            AIX) name="AIX" ;;
            Linux)
                if command_exists busybox; then
                    name="BusyBox Linux"
                else
                    name="$_uname_system"
                fi
                ;;
            *) name="$_uname_system" ;;
        esac
    fi
    
    echo "$name"
}

# Get distribution version
get_distro_version() {
    local best="${1:-false}"
    local pretty="${2:-false}"
    local version=""
    local best_version=""
    local max_dots=-1
    local dots
    
    load_os_release_info
    load_lsb_release_info
    load_distro_release_info
    load_uname_info
    
    # Collect version candidates and find best if requested
    for candidate in "$_os_version_id" "$_lsb_release" "$_distro_version"; do
        if [ -n "$candidate" ]; then
            if [ "$best" = "true" ]; then
                dots=$(count_dots "$candidate")
                if [ "$dots" -gt "$max_dots" ] || [ -z "$best_version" ]; then
                    best_version="$candidate"
                    max_dots="$dots"
                fi
            elif [ -z "$version" ]; then
                version="$candidate"
            fi
        fi
    done
    
    # Handle Debian version file
    local distro_id
    distro_id=$(get_distro_id)
    if [ "$distro_id" = "debian" ] && [ -f "$UNIXCONFDIR/debian_version" ]; then
        local debian_version
        debian_version=$(read_file_safe "$UNIXCONFDIR/debian_version")
        if [ -n "$debian_version" ]; then
            if [ "$best" = "true" ]; then
                dots=$(count_dots "$debian_version")
                if [ "$dots" -gt "$max_dots" ] || [ -z "$best_version" ]; then
                    best_version="$debian_version"
                fi
            elif [ -z "$version" ]; then
                version="$debian_version"
            fi
        fi
    fi
    
    # Handle BusyBox version
    if [ "$distro_id" = "busybox" ] && command_exists busybox; then
        local busybox_version
        busybox_version=$(busybox --help 2>&1 | head -1 | sed 's/.*v\([0-9][0-9.]*\).*/\1/')
        if [ -n "$busybox_version" ]; then
            if [ "$best" = "true" ]; then
                dots=$(count_dots "$busybox_version")
                if [ "$dots" -gt "$max_dots" ] || [ -z "$best_version" ]; then
                    best_version="$busybox_version"
                fi
            elif [ -z "$version" ]; then
                version="$busybox_version"
            fi
        fi
    fi
    
    # Handle macOS/Darwin version
    if [ "$distro_id" = "darwin" ] && command_exists sw_vers; then
        local macos_version
        macos_version=$(sw_vers -productVersion 2>/dev/null)
        if [ -n "$macos_version" ]; then
            if [ "$best" = "true" ]; then
                dots=$(count_dots "$macos_version")
                if [ "$dots" -gt "$max_dots" ] || [ -z "$best_version" ]; then
                    best_version="$macos_version"
                fi
            elif [ -z "$version" ]; then
                version="$macos_version"
            fi
        fi
    fi
    
    # Use best version if requested
    if [ "$best" = "true" ] && [ -n "$best_version" ]; then
        version="$best_version"
    fi
    
    # Add codename if pretty and available
    if [ "$pretty" = "true" ] && [ -n "$version" ]; then
        local codename
        codename=$(get_distro_codename)
        if [ -n "$codename" ]; then
            version="$version ($codename)"
        fi
    fi
    
    echo "$version"
}

# Get distribution codename
get_distro_codename() {
    local codename=""
    
    load_os_release_info
    load_lsb_release_info
    load_distro_release_info
    load_uname_info
    
    if [ -n "$_os_version_codename" ]; then
        codename="$_os_version_codename"
    elif [ -n "$_os_ubuntu_codename" ]; then
        codename="$_os_ubuntu_codename"
    elif [ -n "$_lsb_codename" ]; then
        codename="$_lsb_codename"
    elif [ -n "$_distro_codename" ]; then
        codename="$_distro_codename"
    fi
    
    # macOS/Darwin specific codename detection
    if [ -z "$codename" ] && [ "$_uname_system" = "Darwin" ]; then
        codename=$(get_macos_codename)
    fi
    
    echo "$codename"
}

# Get distributions this is like
get_distro_like() {
    load_os_release_info
    echo "$_os_id_like"
}

# Get all distribution information
get_distro_info() {
    local json_format="${1:-false}"
    local id name version codename like
    
    id=$(get_distro_id)
    name=$(get_distro_name)
    version=$(get_distro_version)
    codename=$(get_distro_codename)
    like=$(get_distro_like)
    
    if [ "$json_format" = "true" ]; then
        cat <<EOF
{
  "id": "$id",
  "name": "$name",
  "version": "$version",
  "codename": "$codename",
  "like": "$like"
}
EOF
    else
        echo "ID: $id"
        echo "Name: $name"
        echo "Version: $version"
        echo "Codename: $codename"
        if [ -n "$like" ]; then
            echo "Like: $like"
        fi
    fi
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

# Display usage information
show_help() {
    cat <<EOF
Usage: $0 [COMMAND] [OPTIONS]

POSIX-portable distribution detection script for minimal environments

Commands:
  id         Show distribution ID
  name       Show distribution name  
  version    Show distribution version
  codename   Show distribution codename
  like       Show distributions this is like (ID_LIKE)
  info       Show all distribution information
  help       Show this help

Options:
  --pretty   Include version and codename in name output
  --best     Use best available version (highest precision)
  --json     Output in JSON format (for info command)

Examples:
  $0 id                    # Show distribution ID (e.g., "ubuntu")
  $0 name --pretty         # Show pretty name with version
  $0 version --best        # Show best available version
  $0 info --json           # Show all info in JSON format

Exit codes:
  0: Detection successful
  1: Error occurred

Note: This is a POSIX-compatible version that works with minimal shells like BusyBox.
EOF
}

# Main function
main() {
    local command="${1:-info}"
    local pretty=false
    local best=false
    local json_format=false
    
    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --pretty)
                pretty=true
                shift
                ;;
            --best)
                best=true
                shift
                ;;
            --json)
                json_format=true
                shift
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            -*)
                printf "Unknown option: %s\n" "$1" >&2
                printf "Use '%s help' for usage information\n" "$0" >&2
                return 1
                ;;
            *)
                if [ "$command" = "${1:-info}" ]; then
                    shift
                else
                    command="$1"
                    shift
                fi
                ;;
        esac
    done
    
    case "$command" in
        id)
            result=$(get_distro_id)
            echo "$result"
            return 0
            ;;
        name)
            result=$(get_distro_name "$pretty")
            echo "$result"
            return 0
            ;;
        version)
            result=$(get_distro_version "$best" "$pretty")
            echo "$result"
            return 0
            ;;
        codename)
            result=$(get_distro_codename)
            echo "$result"
            return 0
            ;;
        like)
            result=$(get_distro_like)
            echo "$result"
            return 0
            ;;
        info)
            get_distro_info "$json_format"
            return 0
            ;;
        help)
            show_help
            return 0
            ;;
        *)
            printf "Unknown command: %s\n" "$command" >&2
            printf "Use '%s help' for usage information\n" "$0" >&2
            return 1
            ;;
    esac
}

# Execute main function if script is run directly (not sourced)
if [ "${0##*/}" = "distro.sh" ]; then
    main "$@"
    exit $?
fi