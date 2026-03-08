# this is the shell you enter when you run `nix develop`

{
  pkgs,
  packages ? [ ],
  shellHook ? "",
  shell ? { },
}:

pkgs.mkShell (
  {
    shellHook = ''
      export NIX_CONFIG="experimental-features = nix-command flakes"
      ${shellHook}
    '';

    packages = with pkgs; [ deploy-rs ] ++ packages;
  }
  // shell
)
