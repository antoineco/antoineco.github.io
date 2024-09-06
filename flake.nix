{
  description = "GitHub Pages";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz"; # nixos-unstable

  inputs.ruby-nix = {
    url = "github:inscapist/ruby-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.bundix = {
    url = "github:inscapist/bundix/main";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/0.1.*.tar.gz";

  outputs = { self, nixpkgs, ruby-nix, bundix, flake-schemas }:
    let
      allSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        # Current 'ruby' package version: 3.3.4
        # Should match https://github.com/actions/jekyll-build-pages/blob/v1.0.13/Dockerfile
        pkgs = import nixpkgs { inherit system; };
      });
    in
    {
      inherit (flake-schemas) schemas;

      devShells = forAllSystems ({ pkgs }:
        let
          ruby-env = (ruby-nix.lib pkgs {
            name = "github-pages";
            gemset = ./gemset.nix;
          }).env;

          bundix-cli = bundix.packages.${pkgs.system}.default;

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
          default = pkgs.mkShell {
            buildInputs = [
              ruby-env
              bundix-cli
              bundleLock
              bundleUpdate
            ];
          };
        }
      );
    };
}
