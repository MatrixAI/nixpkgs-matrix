{ config, lib, pkgs, ... }:

let
  cfg = config.programs.procpath;
  procpathPackage = pkgs.python3Packages.procpath;
in
{
  options.programs.procpath = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to install Procpath and expose it through a privileged
        `security.wrappers.procpath` wrapper with `CAP_SYS_PTRACE`.

        This module is intentionally tied to the overlay-provided
        `pkgs.python3Packages.procpath` package. The wrapper is enabled together
        with the package because Procpath's subtree recording model preserves
        ancestor branches before applying the final query, so procfile reads such
        as `smaps_rollup` can extend beyond the target descendants during useful
        workflows.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ procpathPackage ];

    security.wrappers.procpath = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_ptrace+ep";
      source = "${procpathPackage}/bin/procpath";
    };
  };
}
