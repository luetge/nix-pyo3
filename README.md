# Rust python extension with nix

Setup to compile a rust library

* as a standalone binary
* as a python extension with manylinux support
* as a docker image

while only compiling a single time (and allowing the caching of dependencies by caching the nix store).