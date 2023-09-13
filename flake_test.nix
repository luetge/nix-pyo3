# Check: https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines
{ inputs.nixpkgs.url =
    "github:NixOS/nixpkgs/e39a5efc4504099194032dfabdf60a0c4c78f181";

  outputs = { nixpkgs, ... }:
      let test = nixpkgs.legacyPackages.aarch64-darwin.nixosTest {
        name = "test";

        nodes.machine = { config, pkgs, ...}: {
          nixpkgs.pkgs = nixpkgs.legacyPackages.aarch64-linux.pkgs;

          virtualisation.host.pkgs =
            nixpkgs.legacyPackages.aarch64-darwin;

          users.users.alice = {
						isNormalUser = true;
						extraGroups = [ "wheel" ];
						packages = with pkgs; [
							firefox
							tree
						];
					};

          system.stateVersion = "22.11";
        };

        testScript = ''
          machine.wait_for_unit("default.target")
          machine.succeed("su -- alice -c 'which firefox'")
          machine.fail("su -- root -c 'which firefox'")
        '';
      };

      in {
    packages.aarch64-darwin.test = test;
    checks.aarch64-darwin.default = test;
  };
}
