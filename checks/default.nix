{ lib
, system
, pkgs
, publicLib
, defaultOverlay
, topLevelPackages
, legacyPackages
, nixosModule
, homeModule
, templatesSet
}:

{
  "contract-outputs" = import ./contract-outputs.nix {
    inherit
      system
      pkgs
      publicLib
      defaultOverlay
      topLevelPackages
      legacyPackages
      templatesSet
      ;
  };

  "contract-packages" = import ./contract-packages.nix {
    inherit pkgs topLevelPackages legacyPackages;
  };

  "contract-modules" = import ./contract-modules.nix {
    inherit lib system pkgs nixosModule homeModule;
  };

  "policy-pin" = import ./policy-pin.nix {
    inherit pkgs;
  };

  "smoke-hello" = import ./smoke-hello.nix {
    inherit pkgs topLevelPackages legacyPackages;
  };
}
