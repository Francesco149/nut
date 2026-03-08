{
  assertions = [
    {
      assertion = false;
      message = ''
        =========================================================================
        generate this with:
          nixos-generate-config --show-hardware-config > \
            hosts/nixos/hardware-configuration.nix
        or copy from /etc/nixos/hardware-configuration.nix on the target machine
        =========================================================================
      '';
    }
  ];
}
