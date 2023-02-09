#!/usr/bin/env bash

setup_boxing(){
    local install_dir="$HOME"/.local/lib/setups/repos

    if ! created -d "$install_dir"; then
        mkdir -p "$install_dir"
    fi

    if ! created -d "$install_dir/boxing/.git"; then
        rm -rf "$install_dir"/boxing
        git -C "$install_dir" clone https://github.com/hedinfaok/boxing.git
    else
        git -C "$install_dir/boxing" pull
    fi

    if ! created -L "$HOME"/.local/bin/boxing; then
        ln -sTf "$install_dir/boxing/boxing" "$HOME"/.local/bin/boxing
    fi
    "$HOME"/.local/bin/boxing --version && echo Boxing installed.
}

source <(curl -s "https://raw.githubusercontent.com/hedinfaok/boxing/HEAD/setups/setups")

if [ $# -gt 0 ]; then flag="--force"; fi
setups "$flag" boxing
