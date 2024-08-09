{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
    flakebox = {
      url = "github:rustshop/flakebox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flakebox, flake-utils }:
     flake-utils.lib.eachDefaultSystem (system:
       let
         flakeboxLib = flakebox.lib.${system} { };

        rustSrc = flakeboxLib.filterSubPaths {
          root = builtins.path {
            name = "cross-nix-tests";
            path = ./.;
          };
          paths = [
            "Cargo.toml"
            "Cargo.lock"
            ".cargo"
            "src"
          ];
        };

        legacyPackages = (flakeboxLib.craneMultiBuild { }) (craneLib':
          let
            craneLib = (craneLib'.overrideArgs {
              pname = "cross-nix-tests";
              src = rustSrc;
            });
          in
          rec {
            workspaceDeps = craneLib.buildWorkspaceDepsOnly { };
            workspaceBuild = craneLib.buildWorkspace {
              cargoArtifacts = workspaceDeps;
            };
            cross-nix-tests = craneLib.buildPackage { };
          });
       in
       {
        inherit legacyPackages;
        packages.default = legacyPackages.cross-nix-tests;
         devShells = flakeboxLib.mkShells {
           packages = [ ];
         };
        }
    );
}
