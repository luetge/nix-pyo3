{ nixpkgs, pkgs, system, integration-tests }:

let
vm-system = "aarch64-linux";
vm-pkgs = nixpkgs.legacyPackages.${vm-system}.pkgs;
tests = integration-tests vm-system;
base = {
    nixpkgs.pkgs = vm-pkgs;

    # Make it faster by not waiting for network
    # https://www.reddit.com/r/NixOS/comments/vdz86j/how_to_remove_boot_dependency_on_network_for_a/
    systemd.targets.network-online.wantedBy = pkgs.lib.mkForce [];
    systemd.services.NetworkManager-wait-online.wantedBy = pkgs.lib.mkForce [];

    system.stateVersion = "22.11";
};
kafka_hostname = "kafka";
kafka_ip = 9092;
in
{
  test = pkgs.nixosTest {
    name = "test";

    nodes = {
      machine = { config, pkgs, ... }: {
        environment.sessionVariables = {
          NIX_TESTS_KAFKA = "${kafka_hostname}:${toString kafka_ip}";
        };
      } // base;

      kafka = { config, pkgs, ... }: {
        networking.firewall.enable = false;
        services.apache-kafka = {
          enable = true;
          port = kafka_ip;
          hostname = kafka_hostname;
          extraProperties = ''
            offsets.topic.replication.factor=1
          '';
        };
        services.zookeeper.enable = true;
      } // base;
    };

    testScript = ''
      start_all()
      machine.shell_interact() # Allow interactive exploration
      machine.succeed("${tests}/bin/${tests.name}")
    '';
  };
}
