{ system
, pkgs
, packageName
, crane
, python
, rustToolchain ? (pkgs.rust-bin.fromRustupToolchainFile ../rust-toolchain.toml)
}:
let
  toolchain = rustToolchain.override { extensions = [ "rust-src" ]; };
  craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

  fileFilter = path: _type: builtins.match ".*test/assets/.*$" path != null;

  commonArgs = {
    src = pkgs.lib.cleanSourceWith {
      src = ../.;
      filter = path: type: (fileFilter path type) || (craneLib.filterCargoSources path type);
    };
    pname = packageName;

    nativeBuildInputs = (with pkgs; [ zig ]);

    propagatedBuildInputs = (with pkgs; [ zig ]);

    # Build inputs for the crates
    buildInputs =
      (with pkgs; [ libiconv clang lld pkgconfig git zlib python zig ])
      ++ pkgs.lib.optional pkgs.stdenv.isDarwin
        (with pkgs.darwin.apple_sdk.frameworks; [
          Security
          Foundation
          CoreFoundation
        ]);

    # Compile with zig
    # cargoBuildCommand = "HOME=/tmp/_nix_zigbuild cargo zigbuild --target aarch64-apple-darwin --release";

    # Explicitly set python executable so pyo3 does not rebuild on every path change
    PYO3_PYTHON = "${python}/bin/python";

    # Build optimization
    CARGO_INCREMENTAL = "0";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    RUSTFLAGS =
      if pkgs.stdenv.isDarwin then
        "-C force-frame-pointers=yes -C link-arg=-Wl"
      else
        "-C link-arg=-fuse-ld=lld -C link-arg=-Wl,--compress-debug-sections=zlib -C force-frame-pointers=yes";
  };

  # Build dependencies separately for faster builds in CI/CD
  cargoArtifacts = craneLib.buildDepsOnly (commonArgs // { doCheck = false; });

  # Package the whole workspace with all its binaries
  heavy_computer =
    craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });

  # Repackage a single binary from the workspace derivation containing all binaries
  heavy_computer_single = binary:
    pkgs.stdenv.mkDerivation {
      # Make sure we have the correct dependencies
      inherit (heavy_computer) buildInputs propagatedBuildInputs version;
      name = "${packageName}-${binary}-${heavy_computer.version}";

      # This makes `nix run` work automagically by calling the correct binary
      pname = binary;

      # No building, just install by copy
      phases = [ "installPhase" ];

      # Copy the file
      installPhase = ''
        mkdir -p $out/bin
        cp ${heavy_computer}/bin/${binary} $out/bin
      '';
    };
in
{ inherit heavy_computer heavy_computer_single; rustToolchain = toolchain; }
