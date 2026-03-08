{ config, ... }:

{
  users.users.root.openssh.authorizedKeys.keys = config.nut.ssh.authorizedKeys;

  services.openssh = {
    enable = true;
    ports = [ config.nut.ports.ssh ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes";
      ClientAliveInterval = 60; # could help avoiding ssh lockups from a laggy connection?
      ClientAliveCountMax = 5;
    };
  };

  # ssh wrapper that handles poor routing and drop outs better
  programs.mosh.enable = true;

  networking.firewall = {
    allowedTCPPorts = [ config.nut.ports.ssh ];
  };
}
