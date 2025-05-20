{
  inputs = {
    # We use stable nixpkgs here because otherwise we may end up with a
    # bleeding-edge glibc interpreter, and nobody else will be able to run our
    # binaries.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    naersk.url = "github:nix-community/naersk";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    naersk,
    nixpkgs,
  }:
  # We wrap the entire output set in this flake-utils function, which builds the flake
  # for each architecture type supported by nix.
    flake-utils.lib.eachDefaultSystem (
      system: let
        packageName = "rograph";
        # This sets up nixpkgs, where we will pull our dependencies from
        pkgs = (import nixpkgs) {
          inherit system;
        };

        # This sets up naersk, which we will use later.
        naersk' = pkgs.callPackage naersk {};

        # Here we can add non-rust dependencies that our program requires at run time.
        buildInputs = with pkgs; [
          pkg-config
          openssl
        ];

        # Here we can add non-rust dependencies that our program requires at build time.
        nativeBuildInputs = with pkgs; [
          openssl
          patchelf #
        ];
      in rec {
        # Build this with `nix build`, run it with `nix run`
        defaultPackage = packages.${packageName};
        # Stops the package from being built in a way where it will only run on NixOS
        dontAutoPatchelf = true;
        packages = {
          ${packageName} = naersk'.buildPackage {
            # Naersk will look for a `Cargo.toml` in this directory
            src = ./.;
            # Our buildinputs from above are specified here
            inherit nativeBuildInputs;
          };
          # If we want to run it in a Docker image (could be useful for testing later)
          # we can do that.
        };

        # This will be entered by direnv, or by manually running `nix shell`. This ensures
        # that our development environment will have all the correct tools at the correct
        # version for this project.
        devShell = pkgs.mkShell {
          # Here we add any tools that we want in our dev-shell but aren't required to build
          # our application.
          nativeBuildInputs = with pkgs;
            [
              cargo
              clippy
              cmake
              nixpkgs-fmt
              rustc
              rustfmt
              cargo-edit
            ]
            ++ buildInputs
            ++ nativeBuildInputs;
          # The above line merges our buildInputs into the devshell, so we have them when
          # using cargo tools from inside our devshell.
        };
      }
    );
}
