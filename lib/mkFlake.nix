{
  nixpkgs,
  nut,
  flake-parts,
}:
let
  inherit (nixpkgs) lib;
in
{
  self,
  inputs,
  dir,
  hosts,
  systems ? [ "x86_64-linux" ],
  perSystem ? { ... }: { },
  modules ? [ ],
  hmModules ? { },
  mkHomeDir ? user: if user == "root" then "/${user}" else "/home/${user}",
  mkDefaultModules ? name: [
    ../modules/ssh.nix
    (dir + "/hosts/${name}/configuration.nix")
    (dir + "/hosts/${name}/${name}.nix")
  ],
  mkDefaultHmModules ? name: [
    (dir + "/hosts/${name}/hm/home.nix")
  ],
  flake ? { },
  imports ? [ ],
}:

let
  deploy-rs = inputs.deploy-rs or null;
  home-manager = inputs.home-manager or null;
in
flake-parts.lib.mkFlake { inherit inputs; } {

  inherit imports systems;

  perSystem =
    { pkgs, system, ... }:
    {
      devShells.default = import ./mkDevShell.nix { inherit pkgs; };
      checks = lib.optionalAttrs (deploy-rs != null) deploy-rs.lib.${system}.deployChecks self.deploy;
    }
    // (perSystem { inherit pkgs system; });

  flake = rec {
    nixosConfigurations = builtins.mapAttrs (
      name: host:
      let
        normalized = {
          nut = { };
        }
        // (
          if builtins.isList host then
            { modules = host; }
          else if builtins.isString host then
            {
              nut.deploy.host = host;
              modules = [ ];
            }
          else if builtins.isAttrs host then
            host
          else
            { modules = [ ]; }
        );
      in
      nixpkgs.lib.nixosSystem {
        system = normalized.system or "x86_64-linux";
        modules = [
          # pass through inputs as a module arg just like flake-utils
          # add self so we can have reusable modules in the flake and reference them
          { _module.args = { inherit self inputs; }; }

          # deploy host defaults to configuration name automagically
          (nut.lib.dumb "nut" {
            deploy.host = name;
            ssh.authorizedKeys = [ ];
            ports.ssh = 22;
          })

          # either host gets automatically determined or it's explicitly set
          { inherit (normalized) nut; }
        ]
        ++ [
          {
            # I don't think you would ever not want flakes enabled with this type
            # of configuration so just enable them by default
            nix.settings.experimental-features = [
              "flakes"
              "nix-command"
            ];
          }
        ]
        ++ (mkDefaultModules name)
        ++ modules
        ++ (normalized.modules or [ ])
        ++ (
          # auto-magically generate home-manager config.
          # but only if home-manager is in the calling flake's input,
          # and if there's hmModules entries specified.
          # merge per host and global hmModules
          let
            mergedHmModules = builtins.zipAttrsWith (_: lib.flatten) [
              hmModules
              (normalized.hmModules or { })
            ];
            defaultHmImports = mkDefaultHmModules name;
            mergedWithDefaults = lib.mapAttrs (user: imports: defaultHmImports ++ imports) mergedHmModules;
          in
          lib.optionals (home-manager != null && mergedHmModules != { }) (
            # home manager modules
            [ home-manager.nixosModules.home-manager ]
            ++ lib.mapAttrsToList (
              user: imports: import ../modules/hm/home.nix { inherit user imports; }
            ) mergedWithDefaults
            # generate users
            ++ lib.mapAttrsToList (user: _: {
              users.users.${user} = {
                isNormalUser = user != "root";
                createHome = true;
                home = mkHomeDir user;
              };
            }) mergedHmModules
          )
        );
      }
    ) hosts;

    deploy.nodes =
      let
        # overlay that uses the pre-built binaries as explained in the deploy-rs documentation
        mkDeployPkgs =
          system:
          import nixpkgs {
            inherit system;
            overlays = [
              deploy-rs.overlays.default
              (self: super: {
                deploy-rs = {
                  inherit (nixpkgs.legacyPackages.${system}) deploy-rs;
                  inherit (super.deploy-rs) lib;
                };
              })
            ];
          };
      in
      lib.optionalAttrs (deploy-rs != null) (
        builtins.mapAttrs (
          name: nixosConfig:
          let
            inherit (nixosConfig.config.nixpkgs.hostPlatform) system;
            deployPkgs = mkDeployPkgs system;
          in
          {
            hostname = nixosConfig.config.nut.deploy.host;
            profiles.system = {
              user = "root";
              sshUser = "root";
              path = deployPkgs.deploy-rs.lib.activate.nixos nixosConfig;
            };
          }
        ) nixosConfigurations
      );
  }
  // flake;
}
