self: super:

{
  polykey-cli = self.callPackage (builtins.fetchGit {
    url = "https://github.com/MatrixAI/Polykey-CLI.git";
    ref = "feature-overlay";
    rev = "269a94cf13cb13189ee9fcfd947c3db2130196b9";
  }) {
    commitHash = "269a94cf13cb13189ee9fcfd947c3db2130196b9";
    npmDepsHash = "sha256-PFQ0/x5WG4kbKdvfuYVbKy3HXXkI1HrfTAc1Gh97vyY=";
  };
}
