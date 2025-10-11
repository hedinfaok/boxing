# Boxing

Boxing is a set of utilities that help fill in the boxes for the compute layer
in an architecture diagram. The boxes could be user profiles, virtual machines,
containers, physical machines, networking devices, or IoT embedded thingamajiggers.

Generally, Boxing is software that customizes a computing environment.

## Where does Boxing fit?

I use these tools to provision my personal computers, chromebooks, home servers,
Android phones with Termux, and anything else that can run git and bash.

For something like Hashicorp's Packer, I would use Boxing as the provisioner.

For something like Docker, I would invoke the Boxing utilities in the Dockerfile.

For Termux or my personal computer, I use Boxing in my dotfiles.

## Installation

By default, the installer script uses the Freedesktop.org convention. It installs Boxing into `~/.local/share/boxing` and creates a symlink in `~/.local/bin`.

```
# Install defaults
bash <(curl -s "https://raw.githubusercontent.com/hedinfaok/boxing/HEAD/boxing.setups.sh")

# With `~/.local/bin` in your PATH:
boxing --version

# With `~/.local/bin` not in your PATH:
~/.local/bin/boxing --version

# Directly from default install directory:
~/.local/share/boxing/boxing --version
```

You can customize the installer with the `BOXING_DIR` and `BIN_DIR` environment variables:

```
BOXING_DIR=./boxing \
BIN_DIR=./bin \
    bash <(curl -s "https://raw.githubusercontent.com/hedinfaok/boxing/HEAD/boxing.setups.sh")

# Run from BIN_DIR:
./bin/boxing --version

# Run from BOXING_DIR:
./boxing/boxing --version
```

### Alternative Installtion

Alternatively, just clone this repo and add the directory to your PATH.

## Using as a provisioner

Be sure to copy the `boxing` directory as part of the provisioning process.

* Docker: Use the COPY command in your Dockerfile.
* Packer: Use file provisioner to copy the directory into the target.
* Dotfiles: Copy the `boxing` directory and commit to your git repo.
* Others: Yep, just copy the directory over.

## Utilities

* config: uses git-config to read/write ini files.
* os-facts: displays facts about an os.
* provides: wraps common package managers to find the package that provides a file or command.
* setups: provisions software with shell functions.
* switch: common inferface for reading and writing contexts.
