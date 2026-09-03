# install-nixos.sh
#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo)."
  exit 1
fi

SOURCE_DIR="/etc/nixos-installer-source"
TARGET_DIR="/mnt/etc/nixos"

# 1. Pick User Profile
USER_DIR="$SOURCE_DIR/users"
user_options=()
for d in "$USER_DIR"/*/; do
  [ -d "$d" ] && username=$(basename "$d") && user_options+=("$username" "Profile: $username")
done

[ ${#user_options[@]} -eq 0 ] && { echo "[-] No user profiles found."; exit 1; }

SELECTED_USER=$(whiptail --title "Select User Profile" \
  --menu "Choose whose configuration to install:" 15 60 4 "${user_options[@]}" 3>&1 1>&2 2>&3)
[ $? != 0 ] || [ -z "$SELECTED_USER" ] && exit 0

# 2. Pick Target Hard Drive
options=()
while read -r name size model; do
  options+=("/dev/$name" "$model ($size)")
done < <(lsblk -d -o NAME,SIZE,MODEL -e 7,11 | tail -n +2)

[ ${#options[@]} -eq 0 ] && { echo "[-] No storage drives found."; exit 1; }

SELECTED_DEVICE=$(whiptail --title "NixOS Target Drive" \
  --menu "Selected User: $SELECTED_USER\n\nSelect target drive to partition:\nWARNING: Data will be lost!" \
  17 65 6 "${options[@]}" 3>&1 1>&2 2>&3)
[ $? != 0 ] || [ -z "$SELECTED_DEVICE" ] && exit 0

# 3. Partition, Copy Files, and Install
if whiptail --title "Confirm Installation" \
  --yesno "Ready to install NixOS for '$SELECTED_USER' on:\n  -> $SELECTED_DEVICE\n\nProceed?" 14 60; then
  
  echo "[+] Partitioning $SELECTED_DEVICE..."
  nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --arg disks "[\"$SELECTED_DEVICE\"]" \
    --mode destroy,format,mount "$SOURCE_DIR/disko-config.nix"
    
  [ $? -ne 0 ] && { whiptail --title "Error" --msgbox "Disko failed!" 8 40; exit 1; }

  echo "[+] Generating fresh flake lock..."
  (cd "$SOURCE_DIR" && nix --extra-experimental-features "nix-command flakes" flake lock)

  # Copy the nix/ configuration repo over to /etc/nixos on the new system for tracking
  echo "[+] Setting up permanent configuration at $TARGET_DIR..."
  sudo mkdir -p "$TARGET_DIR"
  sudo cp -aT "$SOURCE_DIR" "$TARGET_DIR"
  sudo chown -R "${SELECTED_USER}:wheel" "$TARGET_DIR"

  # Mark directory as safe in git so nixos-install / flakes can read it without ownership warnings
  sudo git config --global --add safe.directory "$TARGET_DIR"

  # Carry over live Wi-Fi if connected
  if [ -d /etc/NetworkManager/system-connections ] && [ "$(ls -A /etc/NetworkManager/system-connections)" ]; then
    sudo mkdir -p /mnt/etc/NetworkManager/system-connections
    sudo cp -r /etc/NetworkManager/system-connections/* /mnt/etc/NetworkManager/system-connections/
    sudo chmod 600 /mnt/etc/NetworkManager/system-connections/*
  fi

  echo "[+] Installing NixOS for profile #$SELECTED_USER..."
  nixos-install --flake /mnt/etc/nixos/#$SELECTED_USER
  
  if [ $? -eq 0 ]; then
    whiptail --title "Success!" --msgbox "NixOS installed successfully for $SELECTED_USER!\n\nYou can now reboot." 10 50
  else
    whiptail --title "Error" --msgbox "nixos-install failed. Check logs." 8 50
  fi
fi
