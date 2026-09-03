init-submodules:
	git submodule update --init --recursive

build-iso: init-submodules
        nix build .#nixosConfigurations.iso.config.system.build.isoImage

flash-usb: build-iso
        sudo ./flash-usb.sh

