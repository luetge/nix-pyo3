{ nixpkgs, pkgs, system }:

{
  test = pkgs.nixosTest {
    name = "test";

    nodes.machine = { config, pkgs, ... }: {
      nixpkgs.pkgs = nixpkgs.legacyPackages.aarch64-linux.pkgs;

      virtualisation.host.pkgs = pkgs;

      # Make it faster by not waiting for network
      # https://www.reddit.com/r/NixOS/comments/vdz86j/how_to_remove_boot_dependency_on_network_for_a/
      systemd.targets.network-online.wantedBy = pkgs.lib.mkForce [];
      systemd.services.NetworkManager-wait-online.wantedBy = pkgs.lib.mkForce [];

      users.users.alice = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        packages = with pkgs; [ firefox tree ];
      };

      system.stateVersion = "22.11";
    };

    testScript = ''
      machine.wait_for_unit("default.target")
      machine.succeed("su -- alice -c 'which firefox'")
      machine.fail("su -- root -c 'which firefox'")
    '';
  };
}
