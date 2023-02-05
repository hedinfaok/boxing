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

TBD

## Utilities

* config: uses git-config to read/write ini files.
* os-facts: displays facts about an os.
* provides: wraps common package managers to find the package that provides a file or command.
* setups: provisions software with shell functions.
* switch: common inferface for reading and writing contexts.
