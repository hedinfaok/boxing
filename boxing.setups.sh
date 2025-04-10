#!/usr/bin/env bash

setup_boxing(){
    local install_dir="$HOME"/.local/share/setups/repos
    local bin_dir="$HOME"/.local/bin

    if ! created -d "$install_dir"; then
        mkdir -p "$install_dir"
    fi

    if ! created -d "$install_dir/boxing/.git"; then
        rm -rf "$install_dir"/boxing
        git -C "$install_dir" clone https://github.com/hedinfaok/boxing.git
    else
        git -C "$install_dir/boxing" pull
    fi

    if ! created -d "$bin_dir"; then
        mkdir -p "$bin_dir"
    fi

    if ! created -L "$HOME"/.local/bin/boxing; then
        ln -sf "$install_dir/boxing/boxing" "$HOME"/.local/bin/boxing
    fi
    "$HOME"/.local/bin/boxing --version && echo Boxing installed.
}

# Load setups remote library
url="https://raw.githubusercontent.com/hedinfaok/boxing/${BRANCH_NAME:-HEAD}/setups/setups"
source /dev/stdin <<< "$(curl -s "$url")"
setups --force boxing
