{ nixpkgs
, defaultOverlay
}:

{ system
, overlays ? [ ]
, config ? { }
}:

import nixpkgs {
  inherit system;
  inherit config;
  overlays = [ defaultOverlay ] ++ overlays;
}
