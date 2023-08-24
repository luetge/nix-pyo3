{
  description = "Rust code with python bindings";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    flake-utils.url = "github:numtide/flake-utils";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , rust-overlay
    , crane
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      # Get packages
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };
      packageName = "heavy_computer";
      python = pkgs.python310;

      # Creating the rust defitions
      create-rust = args:
        import ./nix/rust.nix
          {
            inherit system pkgs python packageName crane;
          } // args;
      rust = create-rust { };
      docker = pkgs.dockerTools.buildLayeredImage {
        name = packageName;
        tag = "latest";
        config = {
          Cmd = [ "${rust.heavy_computer_binary "say-hello"}/bin/say-hello" ];
        };
        maxLayers = 120;
      };

      # Create a shell to build the project with a given rust toolchain
      create-shell = { rustToolchain ? rust.rustToolchain }:
        pkgs.mkShell ({
          # Environment variables
          CARGO_TARGET_DIR = "/tmp/interactive_rust_build";
          LLVM_COV = "${pkgs.llvmPackages_14.bintools-unwrapped}/bin/llvm-cov";
          LLVM_PROFDATA =
            "${pkgs.llvmPackages_14.bintools-unwrapped}/bin/llvm-profdata";
          RUSTFLAGS = "-W missing_copy_implementations -W rust_2018_idioms";
          PYO3_PYTHON = "${python}/bin/python";

          # Get the inputs to build all crates
          inputsFrom = [
            (create-rust {
              inherit rustToolchain;
            }).heavy_computer
          ];

          buildInputs = with pkgs;
            [
              rust-analyzer
              cargo-nextest
              cargo-llvm-cov
              openssl
            ] ++ lib.optional (!stdenv.isDarwin) [
              pkgs.sssd
            ];
        });

    in {
      packages = {
        say-hello = rust.heavy_computer_binary "say-hello";
        bindings = rust.heavy_computer_ext python;
        wheel = rust.heavy_computer_wheel python;
        coverage = rust.heavy_computer_coverage_html;
        coverage_lcov = rust.heavy_computer_coverage_lcov;
        coverage_tarpaulin = rust.heavy_computer_coverage_tarpaulin;
        test = rust.heavy_computer_test;
        docker = docker;
      };

      checks = {
        test = if (system == "x86_64-linux") then rust.heavy_computer_coverage_tarpaulin else rust.heavy_computer_test;
      };

      devShells = {
        default = create-shell { };
      };
    });
}
