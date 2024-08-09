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

      # Access Fenix's packages using the stable channel for Rust 1.80.0
      fenixPkgs = fenix.packages.${system};

      mkToolchain = fenixPkgs: fenixPkgs.toolchainOf {
        channel = "stable";
        date = "2024-07-25";  # The correct date for Rust 1.80.0
        sha256 = "sha256-6eN/GKzjVSjEhGO9FhWObkRFaE1Jf+uqMSdQnb8lcB4=";  # Pinned via hash
      };

      toolchain = fenixPkgs.combine [
        (mkToolchain fenixPkgs).rustc
        (mkToolchain fenixPkgs).cargo
        (mkToolchain fenixPkgs.targets.${target}).rust-std
      ];

      naerskLib = pkgs.callPackage naersk {
        cargo = toolchain;
        rustc = toolchain;
      };

    in {
      # Default package for native build
      packages.default =
        naerskLib.buildPackage {
          src = ./.;
        };

      # Cross-compilation for ARMv7 with Rust 1.80.0 stable
      packages.armv7 =
        naerskLib.buildPackage {
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
          pkgs.pkg-config
        ];
      };
    });
}
