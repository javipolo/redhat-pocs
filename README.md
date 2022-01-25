# Testing different things with Assisted Installer

I'm using RHEL8 as the base system where all this runs

## Prerequisites
1. Copy your pull-secret.json in the root of this repo
2. Edit Makefile.globals to match your environment
3. Run `make deps` to install all dependencies
4. Run `ocm login --token YOURTOKEN`
