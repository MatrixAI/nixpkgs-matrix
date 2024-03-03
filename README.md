# nixpkgs-matrix
Matrix AI's public nixpkgs overlay.

## Contents
- [Installation](#installation)
  - [How to use](#how-to-use)
  - [Include in flake.nix](#include-in-flakenix)
- [Development](#development)
- [License](#license)

## Installation

### How to use
This repository is configured to support Flakes, an extra-experimental feature in the Nix package manager. To enable it, either append the following argument to every command involving flakes:

```
nix <command> --extra-experimental-features flakes
```

Or you can permanently enable it by setting this in your configuration.nix:

```
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### Include in flake.nix
If you want to inherit the flake from this repository, add the following to your flake inputs/outputs (or create a `flake.nix` with the following if you don't have one already):

```nix
{
  inputs = {
    nixpkgs-matrix.url = "github:MatrixAI/nixpkgs-matrix";

    # You can specify a custom nixpkgs version or use the provisioned one
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs.follows = "nixpkgs-matrix/nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
  let
    username = "myuser";
    hostname = "myhostname";
    system = "mysystem";

    pkgs = import nixpkgs {
      overlays = [ inputs.nixpkgs-matrix.overlays.default ];
      config.allowUnfree = true;
    };
  in
  {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs username hostname system; };
      modules = [ ./configuration.nix ];
    };
  };
}
```

## Development
This repository contains many folders that organise the relevant paths for the overlay.
- `overlays`- This is where Nix overlays are stored.
- `pkgs` - Custom packages go here.
- `modules` - Custom modules are placed here.

### Project structure
```
/nixpkgs-matrix
├── flake.nix
├── flake.lock
├── overlays
│   └── overlay.nix
├── pkgs
│   ├── package1
│   │   └── default.nix
│   └── package2
│       └── default.nix
└── modules
    ├── module1.nix
    └── module2.nix
```

### Testing the overlay
By default, this repository comes with a `devShell` environment that can be configured to take in packages from an overlay/flake, and replicate the same experience of using the overlay without needing to install the overlay into your system.

To do this, you may use the following command:

```
nix develop
```

## License
Thes source code for this project is licensed under the Apache 2.0 License. You may find the conditions of the license [here](LICENSE).
