{
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, fenix, flake-utils, naersk, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        system = system;
        overlays = [ fenix.overlays.default ];
      };

      target = "armv7-unknown-linux-musleabihf";

      # Define the Rust 1.80.0 stable toolchain explicitly
      fenixPkgs = fenix.packages.${system};

      mkToolchain = fenixPkgs: fenixPkgs.toolchainOf {
        channel = "stable";
        date = "2024-07-25";
        sha256 = "sha256-6eN/GKzjVSjEhGO9FhWObkRFaE1Jf+uqMSdQnb8lcB4=";
      };

      toolchain = fenixPkgs.combine [
        (mkToolchain fenixPkgs).rustc
        (mkToolchain fenixPkgs).cargo
        (mkToolchain fenixPkgs.targets.${target}).rust-std
      ];

      # Configure naersk with the correct toolchain
      naerskLib = pkgs.callPackage naersk {
        cargo = toolchain;
        rustc = toolchain;
      };

    in {
      # Native build for the host system
      packages.default = naerskLib.buildPackage {
        src = ./.;
      };

      # Cross-compilation for ARMv7
      packages.armv7 = naerskLib.buildPackage {
        src = ./.;
        CARGO_BUILD_TARGET = target;
        CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABIHF_LINKER =
          let
            inherit (pkgs.pkgsCross.armv7l-hf-multiplatform.stdenv) cc;
          in
          "${cc}/bin/${cc.targetPrefix}cc";
      };

      # Devshell for local development with Rust 1.80.0 stable
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          toolchain
          pkgs.rustfmt
          pkgs.clippy
        ];
      };

      # Define the checks output using mkShell
      checks = {
        lint = pkgs.mkShell {
          nativeBuildInputs = [ toolchain pkgs.rustfmt pkgs.clippy ];
          shellHook = ''
            mkdir -p $TMPDIR/lint-check
            cp -r $src/* $TMPDIR/lint-check/
            cd $TMPDIR/lint-check
            cargo fmt -- --check
            cargo clippy -- -D warnings
          '';
        };
      };
    });
}

