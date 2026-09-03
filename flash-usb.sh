# flash-usb.sh
#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="$SCRIPT_DIR/result/iso"

if [ ! -d "$ISO_DIR" ]; then
  echo "[-] Directory $ISO_DIR not found. Build your ISO first!"
  exit 1
fi

mapfile -t iso_files < <(find "$ISO_DIR" -type f -name "*.iso")

if [ ${#iso_files[@]} -eq 0 ]; then
  echo "[-] No .iso files found in $ISO_DIR."
  exit 1
fi

if [ ${#iso_files[@]} -eq 1 ]; then
  ISO_PATH="${iso_files[0]}"
else
  iso_options=()
  for iso in "${iso_files[@]}"; do
    iso_options+=("$iso" "$(basename "$iso")")
  done

  ISO_PATH=$(whiptail --title "Select ISO to Flash" \
    --menu "Multiple installer ISOs found. Select which one to burn to USB:" \
    15 60 4 "${iso_options[@]}" 3>&1 1>&2 2>&3)

  [ $? != 0 ] || [ -z "$ISO_PATH" ] && exit 0
fi

# Gather USB drives (filtering partitions and loops)
options=()
while read -r name size model; do
  options+=("/dev/$name" "$model ($size)")
done < <(lsblk -d -o NAME,SIZE,MODEL -e 7,11 | tail -n +2)

[ ${#options[@]} -eq 0 ] && { echo "[-] No drives found."; exit 1; }

SELECTED_USB=$(whiptail --title "USB Flasher" \
  --menu "Target ISO: $(basename "$ISO_PATH")\n\nSelect target USB drive. ALL DATA ON IT WILL BE LOST!" \
  16 65 4 "${options[@]}" 3>&1 1>&2 2>&3)

[ $? != 0 ] || [ -z "$SELECTED_USB" ] && exit 0

if whiptail --title "Final Warning" --yesno "Flash $(basename "$ISO_PATH") to $SELECTED_USB?\n\nThis will erase the USB drive!" 10 50; then
  echo "[+] Flashing ISO to $SELECTED_USB..."
  dd if="$ISO_PATH" of="$SELECTED_USB" bs=4M status=progress conv=fdatasync
  whiptail --title "Success" --msgbox "USB installer successfully created! You can now reboot into it." 8 40
fi
