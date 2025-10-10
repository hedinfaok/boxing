#!/usr/bin/env bash


boxing_setup_tar() {
    local install_dir="$1"
    if ! created -x "$install_dir/boxing"; then
        mkdir -p "$install_dir"
        curl -L https://github.com/hedinfaok/boxing/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$install_dir" || {
            echo "Error: Failed to download and extract."
            exit 1
        } && {
            echo "Boxing code downloaded successfully to $install_dir"
        }
    fi
}

boxing_setup_repo() {
    local install_dir="$1"
    if ! created -d "$install_dir/.git"; then
        rm -rf "$install_dir"
        git -C "$install_dir" clone https://github.com/hedinfaok/boxing.git
    else
        git -C "$install_dir" pull
    fi
}

setup_boxing(){
    local install_dir
    local source_file
    local target_file
    local bin_dir="$HOME"/.local/bin

    # Set SETUPS_REPOS to use git to install, else use curl+tar
    if [ -z "$SETUPS_REPOS" ]; then
        if [ -n "${BOXING_DIR:-}" ] && [ -d "$BOXING_DIR" ]; then
            install_dir="$BOXING_DIR"
        else
            install_dir="$HOME/.local/share/boxing"
        fi
        boxing_setup_tar "$install_dir"
    else
        if [ -d "$SETUPS_REPOS" ]; then
            install_dir="$SETUPS_REPOS/boxing"
            boxing_setup_repo "$install_dir"
        else
            install_dir="$HOME/.local/share/setups/repos/boxing"
            echo "Warning: SETUPS_REPOS is not a valid directory. Using $install_dir" 1>&2
            boxing_setup_repo "$install_dir"
        fi
    fi

    if $install_dir/boxing --version; then
        echo "Boxing downloaded successfully to $install_dir"
    else
        echo "Error: Boxing installation failed." 1>&2
        exit 1
    fi

    if ! created -d "$bin_dir"; then
        mkdir -p "$bin_dir"
    fi

    # Create symlink in bin directory
    if ! created -L $bin_dir/boxing; then
        ln -sf "$install_dir/boxing" "$bin_dir/boxing"
    fi
    "$HOME"/.local/bin/boxing --version && echo Boxing installed.
}

# Load setups remote library
url="https://raw.githubusercontent.com/hedinfaok/boxing/${BRANCH_NAME:-HEAD}/setups/setups"
source /dev/stdin <<< "$(curl -s "$url")"
setups --force boxing
