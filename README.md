# nixos-install

NixOS installer flake for building a graphical live ISO, flashing it to USB, and running an interactive install from the live environment.

## Quick start

1. Initialise the submodule:

   ```bash
   git submodule update --init --recursive
   ```
   or
   ```
   just init-submodules
   ```

2. Add and commit user profile to nix submodule, if not already present.
3. Build and flash the live USB:

   ```bash
   just flash-usb
   ```

   This builds the installer ISO and flashes it to a selected USB drive.
   **WARNING**: This is destructive and will erase any data on the drive.

4. Boot the USB, open **Console**, and install NixOS:

   ```bash
   just install-nixos
   ```

   The installer will prompt you to select a user profile and then install that configuration onto the selected disk.

## User profiles

The live installer uses user configurations from `nix/users/` (via the `nix/` submodule). After initialising the submodule, you will likely want to create your own user profile there and commit it recursively.

> My profile exists under nix/users/george/.
  It contains some of my custom configuration, such as signing and authentication public keys.
  So, don't use it directly.
  However, it can serve as a template for your user configuration.

> **Never** commit secrets or other sensitive data in any configuration files.

## Repository layout

- `flake.nix` — Nix flake for the dev shell and installer ISO.
- `justfile` — shortcuts for building the ISO and flashing USB.
- `justfile-live` — shortcut for running the installer from the live system.
- `flash-usb.sh` — flashes a built ISO to a USB drive.
- `install-nixos.sh` — interactive install script used from the live environment.
- `nix/` — configuration submodule containing user profiles and system config. Cloned to /etc/nixos on resulting NixOS install

