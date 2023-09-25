{ nixpkgs, pkgs, system, integration-tests }:

let
vm-system = "aarch64-linux";
vm-pkgs = nixpkgs.legacyPackages.${vm-system}.pkgs;
tests = integration-tests vm-system;
in
{
  test = pkgs.nixosTest {
    name = "test";

    nodes.machine = { config, pkgs, ... }: {
      nixpkgs.pkgs = vm-pkgs;

      # Make it faster by not waiting for network
      # https://www.reddit.com/r/NixOS/comments/vdz86j/how_to_remove_boot_dependency_on_network_for_a/
      systemd.targets.network-online.wantedBy = pkgs.lib.mkForce [];
      systemd.services.NetworkManager-wait-online.wantedBy = pkgs.lib.mkForce [];

      system.stateVersion = "22.11";
    };

    testScript = ''
      machine.wait_for_unit("default.target")
      machine.succeed("${tests}/bin/${tests.name}")
    '';
  };
}
