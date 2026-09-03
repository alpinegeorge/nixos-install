# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    flake-utils.lib.eachDefaultSystem (sys:
      let
        pkgs = import nixpkgs { system = sys; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            just
            git
            newt
          ];
        };

        formatter = pkgs.nixpkgs-fmt;
      }
    ) // {
      nixosConfigurations.iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"
          ({ pkgs, ... }: {
	    boot.zfs.forceImportRoot = false;

            environment.systemPackages = with pkgs; [
              just
              disko
              newt
            ];

            environment.etc."nixos-installer-source" = {
              source = pkgs.runCommand "nixos-installer-source" {
                nativeBuildInputs = [ pkgs.git ];
              } ''
                # Copy the submodule contents
                mkdir -p $out
                cp -r ${./nix}/. $out/

                # Find the real .git directory inside the parent repo
                # ${./.} points to the root of your installer project
                PARENT_GIT_DIR="${./.}/.git"

                if [ -f "$out/.git" ]; then
                  # Extract relative gitdir path (e.g. ../.git/modules/nix)
                  GITDIR_REL=$(cut -d ' ' -f 2 $out/.git)

                  # Resolve to the actual git folder inside .git/modules/
                  REAL_GIT_DIR="${./nix}/$GITDIR_REL"

                  # Replace the .git pointer file with the actual .git directory
                  rm -rf $out/.git
                  cp -r "$REAL_GIT_DIR" $out/.git

                  # Adjust core.worktree in .git/config so Git knows it is a normal repo
                  ${pkgs.gnused}/bin/sed -i '/worktree =/d' $out/.git/config
                fi
              '';
            };

            system.activationScripts.copyInstallerScript = ''
              mkdir -p /home/nixos
              cp ${./install-nixos.sh} /home/nixos/install-nixos.sh
              chmod +x /home/nixos/install-nixos.sh
              chown nixos:users /home/nixos/install-nixos.sh
              cp ${./justfile-live} /home/nixos/justfile
              chown nixos:users /home/nixos/justfile
            '';
          })
        ];
      };
    };
}
