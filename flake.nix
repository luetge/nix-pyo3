{
  description = "Rust code with python bindings";

  inputs = {
    # TODO: Fix this non-main reference once this PR is merged: https://github.com/NixOS/nixpkgs/pull/193336
    nixpkgs.url =
      "github:NixOS/nixpkgs/e39a5efc4504099194032dfabdf60a0c4c78f181";
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

  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane }:
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
          import ./nix/rust.nix {
            inherit system pkgs python packageName crane;
          } // args;
        rust = create-rust { };
        docker = pkgs.dockerTools.buildLayeredImage {
          name = packageName;
          tag = "latest";
          config = { Cmd = [ "${rust.binary "say-hello"}/bin/say-hello" ]; };
          maxLayers = 120;
        };

        # Integration tests
        integration-tests =
          import ./nix/integration-tests.nix { inherit nixpkgs pkgs system; };

        # Scripts
        scripts = import ./nix/scripts.nix { inherit pkgs; };

        # Create a shell to build the project with a given rust toolchain
        create-shell = { rustToolchain ? rust.rustToolchain }:
          pkgs.mkShell ({
            # Environment variables
            CARGO_TARGET_DIR = "/tmp/interactive_rust_build";
            LLVM_COV =
              "${pkgs.llvmPackages_14.bintools-unwrapped}/bin/llvm-cov";
            LLVM_PROFDATA =
              "${pkgs.llvmPackages_14.bintools-unwrapped}/bin/llvm-profdata";
            RUSTFLAGS = "-W missing_copy_implementations -W rust_2018_idioms";
            PYO3_PYTHON = "${python}/bin/python";

            # Get the inputs to build all crates
            inputsFrom =
              [ (create-rust { inherit rustToolchain; }).heavy_computer ];

            buildInputs = with pkgs;
              [ rust-analyzer cargo-nextest openssl scripts.fmt ]
              ++ lib.optional (!stdenv.isDarwin) [ pkgs.sssd ];
          });

      in {
        packages = {
          say-hello = rust.binary "say-hello";
          bindings = rust.ext python;
          wheel = rust.wheel python;
          # TODO: coverage = rust.coverage_html;
          # TODO: coverage_lcov = rust.coverage_lcov;
          test = rust.test;
          integration-tests = integration-tests.test;
          docker = docker;
        } // scripts;

        checks = {
          test = rust.test;
          integration-tests = integration-tests.test;
          fmt = scripts.fmt_check;
        };

        devShells = { default = create-shell { }; };
      });
}
