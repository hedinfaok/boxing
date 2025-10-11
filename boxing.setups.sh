#!/usr/bin/env bash


boxing_setup_tar() {
    local install_dir="$1"
    if ! created -x "$install_dir/boxing"; then
        mkdir -p "$install_dir"
        curl -sL https://github.com/hedinfaok/boxing/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$install_dir" || {
            echo "Error: Failed to download and extract."
            return 1
        }
    fi
}

boxing_setup_repo() {
    local install_dir="$1"
    if ! created -d "$install_dir/.git"; then
        rm -rf "$install_dir"
        git -C "$(dirname "$install_dir")" clone https://github.com/hedinfaok/boxing.git
    else
        git -C "$install_dir" pull
    fi
}

boxing_setup_install_dir() {
    local boxing_dir="${BOXING_DIR:-}"
    local setups_repos="${SETUPS_REPOS:-"$HOME/.local/share/setups/repos"}"
    local use_git="${USE_GIT:-}"

    if [ -n "$boxing_dir" ];then
        if mkdir -p "$boxing_dir"; then
            install_dir="$boxing_dir"
        else
            echo "Error: BOXING_DIR=${boxing_dir} failed." 1>&2
            return 127
        fi
    elif [ -n "$use_git" ]; then
        if mkdir -p "$setups_repos"; then
            install_dir="$setups_repos/boxing"
        else
            echo "Error: SETUPS_REPOS=${setups_repos} failed." 1>&2
            return 127
        fi
    else
        install_dir="$HOME/.local/share/boxing"
    fi
    echo "$install_dir"
}

setup_boxing(){
    local bin_dir="${BIN_DIR:-$HOME/.local/bin}"
    local install_dir
    local use_git="${USE_GIT:-}"

    # Get install directory
    install_dir="$(boxing_setup_install_dir)"

    # Use git or curl+tar for installation
    if [ -n "$use_git" ]; then
        boxing_setup_repo "$install_dir"
    else
        boxing_setup_tar "$install_dir"
    fi

    # Verify download
    if "$install_dir/boxing" --version >/dev/null; then
        echo "Boxing downloaded successfully to $install_dir"
    else
        echo "Error: Boxing installation failed." 1>&2
        return 1
    fi

    # Verify bin_dir in PATH (bash v3 compatible)
    case ":$PATH:" in
        *":$bin_dir:"*)
            ;;
        *)
            echo "Warning: BIN_DIR=$bin_dir is not in your PATH."
            ;;
    esac

    # Create bin directory if it doesn't exist
    if ! created -d "$bin_dir"; then
        mkdir -p "$bin_dir"
    fi

    # Create symlink in bin directory
    if ! created -L $bin_dir/boxing; then
        if ln -sf "$install_dir/boxing" "$bin_dir/boxing"; then
            echo "Boxing link created successfully at $bin_dir/boxing"
        else
            echo "Error: Failed to create symlink in $bin_dir." 1>&2
            echo "You can still run Boxing from $install_dir/boxing" 1>&2
        fi
    fi
}

# Load setups remote library
url="https://raw.githubusercontent.com/hedinfaok/boxing/${BRANCH_NAME:-HEAD}/setups/setups"
source /dev/stdin <<< "$(curl -s "$url")"

if [[ "${BASH_SOURCE[0]:-bash}" == "${0}" ]]; then
    setups --force boxing
fi
