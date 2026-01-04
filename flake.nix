# SPDX-FileCopyrightText: 2026 Jasper Ben Orschulko
# SPDX-License-Identifier: MIT

{
  description = "A flake for converting mif to gpx";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; };

  outputs = { self, nixpkgs }:

    let
      supportedSystems = [
        "i686-linux"
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forEachSupportedSystem = f:
        nixpkgs.lib.genAttrs supportedSystems
        (system: f { pkgs = import nixpkgs { inherit system; }; });
    in {
      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            gdalMinimal
            curl
            coreutils
            findutils
            gh
            gnumake
            gnused
            xmlstarlet
          ];
        };
      });
    };
}
