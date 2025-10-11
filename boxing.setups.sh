#!/usr/bin/env bash


boxing_setup_tar() {
    local install_dir="$1"
    if ! created -x "$install_dir/boxing"; then
        mkdir -p "$install_dir"
        curl -L https://github.com/hedinfaok/boxing/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1 -C "$install_dir" || {
            echo "Error: Failed to download and extract."
            exit 1
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

boxing_setup_install_dir() {
    local use_git="${USE_GIT:-}"
    local boxing_dir="${BOXING_DIR:-}"
    local setups_repos="${SETUPS_REPOS:-"$HOME/.local/share/setups/repos"}"

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
    local use_git="${USE_GIT:-}"
    local install_dir

    local bin_dir="$HOME/.local/bin"
    local source_file
    local target_file

    install_dir="$(boxing_setup_install_dir)"
    if [ -n "$use_git" ]; then
        boxing_setup_repo "$install_dir"
    else
        boxing_setup_tar "$install_dir"
    fi

    if "$install_dir/boxing" --version >/dev/null; then
        echo -e "Boxing downloaded successfully to $install_dir.\nRun $install_dir/boxing --help for a list of commands."
    else
        echo "Error: Boxing installation failed." 1>&2
        return 1
    fi

    if ! created -d "$bin_dir"; then
        mkdir -p "$bin_dir"
    fi

    # Create symlink in bin directory
    if ! created -L $bin_dir/boxing; then
        ln -sf "$install_dir/boxing" "$bin_dir/boxing"
    fi
    # "$HOME"/.local/bin/boxing --version && echo Boxing installed.
}

# Load setups remote library
url="https://raw.githubusercontent.com/hedinfaok/boxing/${BRANCH_NAME:-HEAD}/setups/setups"
source /dev/stdin <<< "$(curl -s "$url")"

if [[ "${BASH_SOURCE[0]:-bash}" == "${0}" ]]; then
    # setups --force boxing
    setups --force boxing
fi
