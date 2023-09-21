{ pkgs }:

rec {
  fmt = pkgs.writeShellScriptBin "fmt" ''
    set -ex
    ${pkgs.nixfmt}/bin/nixfmt `find . -type f -name '*.nix'` $@
  '';
  fmt_check = pkgs.writeShellScriptBin "fmt_check" ''
    set -ex
    ${fmt}/bin/fmt --check
  '';
}
