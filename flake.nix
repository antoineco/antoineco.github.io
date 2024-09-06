{
  description = "GitHub Pages";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz"; # nixos-unstable

    ruby-nix = {
      url = "github:inscapist/ruby-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bundix = {
      url = "github:inscapist/bundix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.*.tar.gz";

    flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.*.tar.gz";
  };

  outputs =
    {
      self,
      nixpkgs,
      ruby-nix,
      bundix,
      flake-utils,
      flake-schemas,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Current 'ruby' package version: 3.3.4
        # Should match https://github.com/actions/jekyll-build-pages/blob/v1.0.13/Dockerfile
        pkgs = nixpkgs.legacyPackages.${system};

        ruby-env =
          (ruby-nix.lib pkgs {
            name = "github-pages";
            gemset = ./gemset.nix;
          }).env;

        bundix-cli = bundix.packages.${system}.default;

        bundleLock = pkgs.writeShellScriptBin "bundle-lock" ''
          export BUNDLE_PATH=vendor/bundle
          bundle lock
        '';
        bundleUpdate = pkgs.writeShellScriptBin "bundle-update" ''
          export BUNDLE_PATH=vendor/bundle
          bundle lock --update
        '';
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              ruby-env
              bundix-cli
              bundleLock
              bundleUpdate
            ];
          };
        };
      }
    )
    // {
      inherit (flake-schemas) schemas;
    };
}
