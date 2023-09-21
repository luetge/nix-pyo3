{ nixpkgs, pkgs, system }:

{
  test = pkgs.nixosTest {
    name = "test";

    nodes.machine = { config, pkgs, ... }: {
      nixpkgs.pkgs = nixpkgs.legacyPackages.aarch64-linux.pkgs;

      virtualisation.host.pkgs = pkgs;

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
