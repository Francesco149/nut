{
  assertions = [
    {
      assertion = false;
      message = ''
        =========================================================================
        adjust to match your /etc/nixos/configuration.nix from the fresh install.
        run `nixos-generate-config` on the target machine to regenerate this.
        or simply copy it over and adjust/remove any pre configured software
        to your liking.
        =========================================================================
      '';
    }
  ];

  # example of what this file usually looks like from a graphical install

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  system.stateVersion = "25.11";
}
