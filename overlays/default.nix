final: prev:
let
  packageDefs = import ../pkgs { };
in
packageDefs.overlay final prev