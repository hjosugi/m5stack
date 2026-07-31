{
  description = "StackChan/M5Stack向けの再現可能で安全な開発環境";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              acl
              arduino-cli.pureGoPkg
              bison
              ccache
              cmake
              coreutils
              curl
              dfu-util
              esptool
              findutils
              flex
              git
              gnumake
              gnugrep
              gperf
              jq
              libffi
              libusb1
              ninja
              openssl
              pkg-config
              python3
              ripgrep
              shellcheck
              shfmt
              usbutils
              unzip
            ];

            shellHook = ''
              export M5STACK_DEV_SHELL=1
              echo "M5Stack開発環境: make detect / make setup / make build"
            '';
          };
        }
      );
    };
}
