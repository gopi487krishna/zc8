{
  description = "A simple chip 8 interpreter written in zig";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, zig }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          zig.overlays.default
        ];
      };
    in
    {
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = with pkgs; [nixpkgs-fmt zigpkgs."0.14.0" sdl3 emscripten python3];
        # Expose Emscripten path as env var
        # For EM_CACHE see : https://github.com/NixOS/nixpkgs/issues/139943#issuecomment-930432045
        shellHook = ''
          export EMSCRIPTEN_PATH="${pkgs.emscripten}"
          export EM_CACHE="$HOME/.emscripten_cache"
          echo "EMSCRIPTEN_PATH is set to: $EMSCRIPTEN_PATH"
          echo "EM_CACHE is set to: $EM_CACHE"
        '';
      };
  };
}
