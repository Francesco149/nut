# machine-specific config goes here
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    neovim
  ];
}
