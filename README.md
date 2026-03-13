# nut (nix-utils)

Opinionated but flexible NixOS flake library. Aims to de-clutter boilerplate
without undermining the modular philosophy of the nix ecosystem.

Built on top of [flake-parts](https://github.com/hercules-ci/flake-parts), with
optional dependencies on [deploy-rs](https://github.com/serokell/deploy-rs), and
[home-manager](https://github.com/nix-community/home-manager) to wire them up
auto-magically.

It was mainly made for my own convenience, but feedback and contributions are
welcome. I'm still quite new to nix.

---

## quickstart

The simplest possible setup, a single machine with no extras:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nut.url = "github:Francesco149/nut";
    nut.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nut, ... }@inputs:
    nut.lib.mf {
      inherit self inputs;
      dir = ./.;
      hosts.myhost = [];
    };
}
```

This generates `nixosConfigurations.myhost` which automatically imports the
following modules:

### `hosts/myhost/configuration.nix`

Your hardware/boot config.

You can generate a clean one with:

```sh
nixos-generate-config --dir ./hosts/nixos/ --force
```

If it's not a fresh system and you previously configured anything system-wide
that you want to keep, migrate that from your`/etc/nixos/configuration.nix` and
`/etc/nixos/hardware-configuration.nix` to the ones we just generated in
`./hosts/nixos/` .

### `hosts/myhost/myhost.nix`

Machine-specific config. The stuff you would normally add to `configuration.nix`
in a non-flake setup.

### default ssh config

Enables [mosh](https://mosh.org/) and sets up openssh with key-only auth for
root on port 22 and `nut.ssh.authorizedKeys` as the authorized keys. You can
check the ssh config in this repo at `common/ssh.nix`. Port can be customized
from `nut.ports.ssh` .

### default nix config

Enables `experimental-features = flakes nix-command` . You basically never want
to have these off if you're working with flakes.

Deploy with:

```sh
nixos-rebuild switch --flake .#myhost
```

All these implicit imports can be overridden or entirely removed, more on that
in the [dedicated section](#overriding-defaults) .

---

## adding remote deployment

Add [deploy-rs](https://github.com/serokell/deploy-rs) to your inputs and it
just works. No extra config needed. The hostname defaults to the machine name,
and the deploy target is read from `nut.deploy.host` in your NixOS config if
you want to override it.

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  nut.url = "github:Francesco149/nut";
  nut.inputs.nixpkgs.follows = "nixpkgs";

  deploy-rs.url = "github:serokell/deploy-rs";
  deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
};
```

```sh
deploy          # deploy all machines
deploy .#myhost # deploy one machine
```

Note that you need to either have `pkgs.deploy-rs` installed or enter the
included dev shell by running `nix develop`, which provides just that one
package at the moment.

deploy-rs is entirely optional. Removing it from your inputs falls back
gracefully to manual `nixos-rebuild`.

---

## multiple machines

```nix
hosts = {
  # list = modules for this host
  workstation = [
    ./hosts/workstation/extra.nix
  ];

  # string = explicit deploy hostname or ip
  vps = "1.2.3.4";

  # attrset = full options
  server = {
    system = "aarch64-linux";
    modules = [ ./hosts/server/extra.nix ];
    nut.deploy.host = "server.local";
  };
};
```

---

## common modules

Modules shared across all machines:

```nix
nut.lib.mf {
  inherit self inputs;
  dir = ./.;

  hosts = { ... };

  modules = [
    ./modules/common.nix
    ./modules/tailscale.nix
  ];
};
```

---

## home-manager

Add [home-manager](https://github.com/nix-community/home-manager) to your
inputs and use `hmModules` to configure users. Like deploy-rs, it is entirely
optional. No home-manager input means no home-manager config.

```nix
inputs = {
  # ...
  home-manager.url = "github:nix-community/home-manager";
  home-manager.inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
nut.lib.mf {
  inherit self inputs;
  dir = ./.;

  hosts.myhost = [];

  # global hmModules applied to all hosts
  hmModules.alice = [
    ./modules/hm/git.nix
    ./modules/hm/shell.nix
  ];
};
```

The home manager module and `hosts/${name}/hm/home.nix` are auto-imported for
each host that has any `hmModules`, users whether they come from the global or
per-host list.

You should at least add `home.stateVersion` to this file:

```nix
# hosts/myhost/hm/home.nix
{ pkgs, ... }:
{
  # ... you settings here

  # the latest stable NixOS version you first installed Home Manager.
  # you can check here at the time of install: https://status.nixos.org/
  # do not change this afterwards
  home.stateVersion = "25.11";
}
```

A user and its home folder is also automatically created for each `hmModules`
entry with sensible defaults. As with everything you can override these
defaults, explained in the [dedicated section](#overriding-defaults) .

User passwords are unset by default so make sure you will still have access to
either your user or root after deployment to set the password with `passwd`.
Alternatively, you can set `users.users.myuser.initialPassword = changeme;` or
something to that effect, which will be ignored after you set a password.

Users are also automatically added to the groups `video` `render` and `wheel`.

The home manager modules are merged with each machine's modules. There is no
`homeConfigurations` . iF you wish to do things differently, you can simply omit
hmModules and use home-manager independently.

Per-host home-manager modules are merged with the global ones:

```nix
# every host gets alice and root with these base settings
hmModules.alice = [
  ./modules/hm/alice-common.nix
];
hmModules.root = [
  ./modules/hm/root-common.nix
];
hosts = {
  workstation = {
    # merged with global hmModules.alice
    hmModules.alice = [
      ./hosts/workstation/hm/alice.nix
    ];
  };
};
```

---

## full example

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nut.url = "github:Francesco149/nut";
    nut.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nut, ... }@inputs:
    nut.lib.mf {
      inherit self inputs;
      dir = ./.;

      hosts = {
        workstation = {
          modules = [ ./hosts/workstation/extra.nix ];
          hmModules.alice = [ ./hosts/workstation/hm/alice.nix ];
        };

        vps = "1.2.3.4";
      };

      modules = [
        ./modules/common.nix
        ./modules/tailscale.nix
      ];

      hmModules.alice = [
        ./modules/hm/git.nix
        ./modules/hm/shell.nix
      ];

      # extend the flake with extra outputs
      perSystem = { pkgs, system, ... }: {
        packages.${system}.mypackage = pkgs.callPackage ./pkgs/mypackage {};
      };
    };
}
```

---

## overriding defaults

The default module paths and home directory logic can be overridden:

```nix
nut.lib.mf {
  inherit self inputs;
  dir = ./.;
  hosts = { ... };

  # override where per-host modules are loaded from
  mkDefaultModules = name: [
    ./common/ssh.nix
    ./machines/${name}/config.nix
  ];

  # override per-host hm modules path
  mkDefaultHmModules = name: [
    ./machines/${name}/hm.nix
  ];

  # override home directory logic
  mkHomeDir = user:
    if user == "root" then "/root"
    else "/home/users/${user}";
};
```

---

## example monolithic plasma desktop

Here's an example of a kde plasma desktop config all inlined in the `flake.nix`
by getting rid of the default modules.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nut.url = "github:Francesco149/nut";
    nut.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nut, ... }@inputs:
    nut.lib.mf {
      inherit self inputs;
      dir = ./.;
      mkDefaultModules = name: [ ]; # also disables the built in ssh config
      hosts.myhost = [
        ./configuration.nix # copied from /etc/nixos along with hardware-configuration
        (
          { pkgs, ... }:
          {
            # your config here, for example:
            nix.settings.experimental-features = [
              "nix-command"
              "flakes"
            ];

            environment.systemPackages = with pkgs; [
              git
              nixfmt
              neovim
            ];

            services.desktopManager.plasma6.enable = true;
            services.displayManager.sddm = {
              enable = true;
              wayland.enable = true;
            };

            users.users.headpats = {
              isNormalUser = true;
              extraGroups = [
                "wheel"
                "networkmanager"
              ];
              initialPassword = "changeme";
            };

          }
        )
      ];
    };
}
```

---

## flake template

The fastest way to get started is with the included templates.

When using a template, the flake is automatically initialized with a base
working configuration that you can begin editing to your needs.

Currently, we have:

- `default`: a barebones system with no graphical interface and the bare minimum
  ssh config
- `hyprland`: a basic hyprland config using home-manager with some customizations,
  login manager, lock screen, status bar, default applications, all the basic
  things that you would usually set up.

Feel free to submit your own templates.

### example: deploying the hyprland template

```sh
nix shell nixpkgs#git # if you don't have git
mkdir flake && cd flake
git init
nix flake init -t github:Francesco149/nut#hyprland
git add .
```

Copy over your hardware config:

```sh
nixos-generate-config --dir ./hosts/nixos/ --force
```

If you had anything in your `/etc/nixos/configuration.nix` that you want to move
over, make sure to add it to `./hosts/nixos/nixos.nix` . Also check what's in
`./hosts/nixos/configuration.nix` to make sure nothing is missing that you might
have specifically configured.

If you need to maintain ssh access to this machine after deployment, make sure
to add your ssh key(s) to `nut.ssh.authorizedKeys` in `hosts/nixos/nixos.nix` .

Deploy:

```sh
nixos-rebuild switch --flake .#nixos
```

Make sure to change alice's password before you reboot, then reboot into your
hyprland desktop. Log in as the demo user alice.

```sh
passwd alice
reboot
```

Poke around in `hosts/nixos/hm/home.nix`, try customizing and adding things.

Check out `flake.nix` , try adding more users or renaming alice to your own
user. Experiment with modularizing your configuration.

Edit `hosts/nixos/nixos.nix` to your liking, add whatever system-wide software
and configuration you want that doesn't fit in home-manager.

If you want to rename your host, edit `flake.nix` and replace `nixos` with your
machine name, then rename `./hosts/nixos` to a matching dir name.

Re-deploy changes:

```sh
nixos-rebuild switch --flake .#nixos
```

Usually, configuration changes are picked up automatically and things like
themes refresh on the fly. Should they not, try relogging or rebooting.

---

## flakes primer

If you are new to flakes, here is the minimum you need to know.

### enabling flakes

Flakes are not enabled by default on NixOS. Add this to your
`/etc/nixos/configuration.nix` before switching to a flake-based config:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Then `nixos-rebuild switch` to apply it.

### flake.lock

When you first run any nix flake command, nix generates a `flake.lock` file
that pins all your inputs to exact versions. Commit this file. It ensures
reproducible builds across machines.

To update inputs to their latest versions:

```sh
nix flake update         # update all inputs
nix flake update nixpkgs # update one input
```

### git is required

Nix flakes only see files that are tracked by git. If you add a new `.nix`
file and nix says it cannot find it, you probably forgot to `git add` it.
You do not need to commit, just stage it:

```sh
git add hosts/myhost/myhost.nix
```

A dirty working tree (uncommitted changes) also disables the eval cache,
making rebuilds slower. Committing regularly keeps things fast.

### rebuilding

```sh
# apply config on the current machine
nixos-rebuild switch --flake .#myhostname

# test without making it the boot default
nixos-rebuild test --flake .#myhostname

# build without applying
nixos-rebuild build --flake .#myhostname
```

---

## known issues

### home-manager completion in nixd/nil

Neither nixd nor nil reliably provides completion for home-manager options in
module files. Various approaches were attempted including `homeConfigurations`,
pointing nixd at `options.home-manager.users.type.getSubOptions []`, and using
`sharedModules` instead of `imports`. None produced consistent results.

If you have got this working, please open an issue or PR with your setup.

---

## acknowledgements

nut stands on the shoulders of an incredible ecosystem maintained by
dedicated volunteers and developers. A huge thank you to:

- **[NixOS](https://nixos.org/) and [nixpkgs](https://github.com/NixOS/nixpkgs)**
  for the foundation everything is built on. The scale of nixpkgs and the
  reliability of NixOS is a testament to thousands of contributors.

- **[flake-parts](https://github.com/hercules-ci/flake-parts)** for making
  composing flake outputs actually pleasant. The module system approach is
  exactly right.

- **[deploy-rs](https://github.com/serokell/deploy-rs)** for remote NixOS
  deployment that just works.

- **[home-manager](https://github.com/nix-community/home-manager)** for
  declarative user environment management. You don't know you need it until
  you have it.

- **[nix](https://github.com/NixOS/nix)** itself, a genuinely novel idea that
  keeps proving its worth.

If any of these projects have made your life better, please consider supporting
them. Most are maintained by small teams or individuals giving their time freely:

- [NixOS Foundation](https://nixos.org/donate/) supports nixpkgs and NixOS
- [Serokell](https://serokell.io/) maintains deploy-rs
- [home-manager
  contributors](https://github.com/nix-community/home-manager/graphs/contributors).
  Consider sponsoring active maintainers directly on GitHub
- [flake-parts](https://github.com/hercules-ci/flake-parts) by Hercules CI
