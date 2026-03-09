{ final
, prev
, system ? final.stdenv.hostPlatform.system
}:

let
  polykey-cli-flake = builtins.getFlake
    "github:MatrixAI/Polykey-CLI/b72e05b3709dcc862fac428022c4b8bbe3e35f6e";
in {
  python3Packages = prev.python3Packages.overrideScope (pyFinal: _pyPrev: {
    jsonpyth = pyFinal.callPackage ./pkgs/development/python-modules/jsonpyth { };
    procpath = pyFinal.callPackage ./pkgs/development/python-modules/procpath { };
  });

  polykey-cli = polykey-cli-flake.packages.${system}.default;
  polykey-cli-docker = polykey-cli-flake.packages.${system}.docker;
}
