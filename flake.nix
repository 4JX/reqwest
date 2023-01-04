{
  description = "Build env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, crane, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        rustVersion = "1.65.0";

        rust = pkgs.rust-bin.stable.${rustVersion}.default.override {
          extensions = [
            "rust-src" # rust-analyzer
          ];
        };

        nixLib = nixpkgs.lib;
        craneLib = (crane.mkLib pkgs).overrideToolchain rust;


        envVars = rec {
          RUST_BACKTRACE = 1;
          MOLD_PATH = "${pkgs.mold.out}/bin/mold";
          RUSTFLAGS = "-Clink-arg=-fuse-ld=${MOLD_PATH} -Clinker=clang";
        };

        # Allow more files to be included in the build workspace
        workspaceSrc = ./.;
        # workspaceSrcString = builtins.toString workspaceSrc;

        workspaceFilter = path: type:
          (craneLib.filterCargoSources path type);

        # The main application derivation
        reqwest-impersonate = craneLib.buildPackage
          ({
            src = nixLib.cleanSourceWith
              {
                src = workspaceSrc;
                filter = workspaceFilter;
              };

            doCheck = false;

            buildInputs = with pkgs;
              [

              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ ];

            nativeBuildInputs = with pkgs;
              [

              ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ ];

            cargoVendorDir = null;

          } // envVars);
      in
      {
        checks = {
          inherit reqwest-impersonate;
        };

        packages.default = reqwest-impersonate;

        devShells.default = reqwest-impersonate;
      });
}



