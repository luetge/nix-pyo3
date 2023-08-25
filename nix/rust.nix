{ system, pkgs, packageName, crane, python
, rustToolchain ? (pkgs.rust-bin.stable.latest.default) }:
let
  toolchain = rustToolchain.override {
    extensions = [
      "rust-src"
      "cargo"
      "rustc"
      "rustfmt"
      "clippy"
      "rust-analyzer"
      "llvm-tools-preview"
    ];
  };
  craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
  # We compile with glibc 2.17 for the pythone extension to be manylinux compliant
  target = if (!pkgs.stdenv.isDarwin) then "-target ${system}-gnu.2.17" else "";
  zigcc = pkgs.writeShellScriptBin "zigcc" ''
    set -ex
    # zig uses the home directory under the hood, make it writable
    export XDG_CACHE_HOME=/tmp/nixrustcompilecache
    ${pkgs.zig}/bin/zig cc ${target} "$@"
  '';

  fileFilter = path: _type: builtins.match ".*test/assets/.*$" path != null;

  commonArgs = {
    pname = packageName;
    src = pkgs.lib.cleanSourceWith {
      src = ../.;
      filter = path: type:
        (fileFilter path type) || (craneLib.filterCargoSources path type);
    };

    # Build inputs for the crates
    buildInputs =
      (with pkgs; [ libiconv clang lld pkgconfig git zlib python zigcc ])
      ++ pkgs.lib.optional pkgs.stdenv.isDarwin
      (with pkgs.darwin.apple_sdk.frameworks; [
        Security
        Foundation
        CoreFoundation
      ]);

    cargoExtraArgs = "--features extension-module";

    # Explicitly set python executable so pyo3 does not rebuild on every path change
    PYO3_PYTHON = "${python}/bin/python";

    # Build optimization
    CARGO_INCREMENTAL = "0";
    CARGO_PROFILE_RELEASE_LTO = "thin";
    RUSTFLAGS = if pkgs.stdenv.isDarwin then
      "-C force-frame-pointers=yes -C link-arg=-Wl -C link-arg=-undefined -C link-arg=dynamic_lookup"
    else
      "-C link-arg=-fuse-ld=lld -C link-arg=-Wl,--compress-debug-sections=zlib -C force-frame-pointers=yes";
  };

  # TODO: llvm cov fails with zig, fix this to avoid double compilation
  commonArgsZig = commonArgs // (if pkgs.stdenv.isDarwin then {} else {
    HOST_CC = "${zigcc}/bin/zigcc";
    CC = "${zigcc}/bin/zigcc";
    RUSTFLAGS = "-C linker=${zigcc}/bin/zigcc " + commonArgs.RUSTFLAGS;
  });

  # Build dependencies separately for faster builds in CI/CD
  cargoArtifactsZig = craneLib.buildDepsOnly (commonArgsZig // { doCheck = false; });
  cargoArtifacts = craneLib.buildDepsOnly (commonArgs // { doCheck = false; });

  # Package the whole workspace with all its binaries
  heavy_computer =
    craneLib.buildPackage (commonArgsZig // { cargoArtifacts = cargoArtifactsZig; });

  # Test 
  test = craneLib.cargoTest (commonArgsZig // {
    cargoArtifacts = cargoArtifacts;
    preConfigurePhases = [ "fixBindings" ];
    fixBindings = ''
      rm -f target/release/deps/libbindings.rlib 
    '';

  });

  coverage_args =
    "--workspace --ignore-filename-regex '.*vendor-cargo-deps/.*'";
  coverage_html = craneLib.cargoLlvmCov (commonArgs // rec {
    inherit cargoArtifacts;
    cargoLlvmCovExtraArgs = "--html ${coverage_args}";
    name = "rust-coverage";
    meta.mainProgram = name;
    postInstall = ''
      mkdir -p $out
      cp -r target/llvm-cov/html/* $out/

      # Make it runnable with nix run (at least on macOS)
      # TODO: Make it work on linux
      mkdir -p $out/bin
      echo "#!/bin/bash" >> $out/bin/${name}
      echo "/usr/bin/open $out/index.html" >> $out/bin/${name}
      chmod +x $out/bin/${name}
    '';
  });

  coverage_lcov = craneLib.cargoLlvmCov (commonArgs // {
      inherit cargoArtifacts;
      cargoLlvmCovExtraArgs = "--lcov --output-path $out ${coverage_args}";
    });

  # Repackage a single binary from the workspace derivation containing all binaries
  binary = binary:
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

  # Compile the python extension
  ext = python:
    pkgs.stdenv.mkDerivation {
      # Make sure we have the correct dependencies
      inherit (heavy_computer) version;
      nativeBuildInputs =
        heavy_computer.nativeBuildInputs; # ++ [ pkgs.autoPatchelfHook ];
      name = "${packageName}-ext-${heavy_computer.version}";
      pname = "${packageName}-ext";

      # No building, just install by copy
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out

        # First we build the .so file
        export PYTHON_BIN=${python}/bin/python
        PLATFORM_SO_TAG=$($PYTHON_BIN -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
        echo TAG: $PLATFORM_SO_TAG
        TARGET_FILE=$out/heavy_computer$PLATFORM_SO_TAG
        cp ${heavy_computer}/lib/* $TARGET_FILE
      '';
    };

  wheel = python:
    pkgs.stdenv.mkDerivation rec {
      # Make sure we have the correct dependencies
      inherit (heavy_computer)
        version buildInputs propagatedBuildInputs nativeBuildInputs;
      name = "${packageName}-wheel-${heavy_computer.version}";
      pname = "${packageName}-wheel";
      phases = [ "installPhase" ];

      platform_version = if pkgs.stdenv.isDarwin then
        "macosx_11_0_arm64"
      else
        "manylinux_2_17_x86_64.manylinux2014_x86_64";

      repair_wheel_command = if (!pkgs.stdenv.isDarwin) then
        "${pkgs.auditwheel}/bin/auditwheel repair --plat manylinux_2_17_x86_64 --strip *.whl -w ./repaired"
      else
        "mkdir -p ./repaired && mv `ls *.whl` ./repaired";

      # Build the wheel
      installPhase = ''
        mkdir -p $out

        set -ex

        export VERSION=${heavy_computer.version}
        export PYTHON_BIN=${python}/bin/python
        echo Compiling version $VERSION for $PYTHON_BIN

        tmp_dir=$(mktemp -d -t wheel-XXXXXXXXXX)

        # Copy extension
        cp ${ext python}/* $tmp_dir/

        # Also copy the config folder
        # mkdir -p $tmp_dir/config/
        # cp -r config/envs $tmp_dir/heavy_computer/config/

        # Prepare files for the wheel
        pushd $tmp_dir

        namever=heavy_computer-$VERSION
        distinfo=$namever.dist-info
        mkdir -p $distinfo
        cat <<EOF > $distinfo/METADATA
        Metadata-Version: 2.1
        Name: heavy_computer
        Version: $VERSION
        EOF

        PLATFORM_SO_TAG_VERSION=`$PYTHON_BIN -c 'import sysconfig; print(sysconfig.get_config_var("py_version_nodot"))'`
        cat <<EOF > $distinfo/WHEEL
        Wheel-Version: 1.0
        Generator: heavy_computer
        Root-Is-Purelib: false
        Tag: cp''${PLATFORM_SO_TAG_VERSION}-cp''${PLATFORM_SO_TAG_VERSION}-${platform_version}
        EOF


        echo Wheel folder contents
        ${pkgs.tree}/bin/tree .

        ${pkgs.python3.pkgs.wheel}/bin/wheel pack .
        ${repair_wheel_command}
        popd

        WHEEL_NAME=$(basename $(ls $tmp_dir/*.whl))
        cp $tmp_dir/repaired/*.whl $out/
        rm -rf $tmp_dir
      '';
    };
in {
  inherit heavy_computer binary ext wheel test coverage_html coverage_lcov;
  rustToolchain = toolchain;
}
