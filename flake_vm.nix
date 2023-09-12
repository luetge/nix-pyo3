{
  outputs = {
    self,
    nixpkgs,
  }: {
    nixosModules.base = {pkgs, ...}: {
      system.stateVersion = "22.05";

      # Configure networking
      networking.useDHCP = false;
      networking.interfaces.eth0.useDHCP = true;

      # Create user "test"
      services.getty.autologinUser = "test";
      users.users.test.isNormalUser = true;

      # Enable passwordless ‘sudo’ for the "test" user
      users.users.test.extraGroups = ["wheel"];
      security.sudo.wheelNeedsPassword = false;

      # Make VM output to the terminal instead of a separate window
      virtualisation.vmVariant.virtualisation.graphics = false;
    };
    nixosConfigurations = {
      linuxVM = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ self.nixosModules.base ];
      };
      darwinVM = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.base
          {
            virtualisation.vmVariant.virtualisation.host.pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          }
        ];
      };
    };
    packages.x86_64-linux.linuxVM = self.nixosConfigurations.linuxVM.config.system.build.vm;
    packages.aarch64-darwin.darwinVM = self.nixosConfigurations.darwinVM.config.system.build.vm;
  };
}
