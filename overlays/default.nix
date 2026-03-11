# final: prev:
# import ../packages.nix {
#   inherit final prev;
# }


final: prev:
  let
    packageDefs = import ../pkgs {
      system = final.stdenv.hostPlatform.system;
    };
  in
    packageDefs.overlay final prev