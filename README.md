# Rust python extension with nix

Setup to compile a rust library

* as a standalone binary
* as a python extension with manylinux support
* as a docker image

while only compiling a single time (and allowing the caching of dependencies by caching the nix store).

## Commands

* nix run .#say-hello => run the binary
* nix build .#bindings => build the python bindings into ./result
* nix build .#wheel => build the wheel into ./result
* nix build .#test => run tests
* nix build .#coverage => generate html coverage report into ./result (nix run .#coverage to open in a browser)
* nix build .#coverage_lcov => generate lcov report
* nix build .#docker => generate docker image running binary as main command
* nix flake check => run tests

