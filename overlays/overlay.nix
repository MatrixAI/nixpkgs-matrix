{ inputs }:

final: prev:

{
  nixos = configuration:
    let
      modules = import ../modules/module-list.nix { inherit inputs; };
    in
      prev.nixos (
        if builtins.isList configuration
        then configuration ++ modules
        else [configuration] ++ modules
      );

  polykey-cli = inputs.polykey-cli.packages.x86_64-linux.default;
}
