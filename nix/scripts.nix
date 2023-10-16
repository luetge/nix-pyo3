{ pkgs, rust }:

rec {
  format_all = pkgs.writeShellScriptBin "format_all" ''
    set -ex
    ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt *.nix **/*.nix --check || ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt *.nix **/*.nix
    PATH=$PATH:${rust.rustToolchain}/bin cargo fmt
    ${pkgs.black}/bin/black .
  '';
}
