let
  nixosModuleList = import ./nixos/module-list.nix;

  moduleNameFromPath = path:
    let
      pathString = toString path;
      baseName = builtins.baseNameOf pathString;
      nixFileMatch = builtins.match "^(.*)\\.nix$" baseName;
    in
      if baseName == "default.nix"
      then builtins.baseNameOf (builtins.dirOf pathString)
      else if nixFileMatch != null
      then builtins.elemAt nixFileMatch 0
      else baseName;

  toModuleSet = list:
    builtins.listToAttrs (map
      (path: {
        name = moduleNameFromPath path;
        value = import path;
      })
      list);
in
{
  nixosModules = toModuleSet nixosModuleList // {
    default = import ./nixos;
  };

  homeModules = {
    default = import ./home;
  };
}
