{ ... }:

let
  moduleList = import ./module-list.nix;
in
{
  imports = moduleList;
}
