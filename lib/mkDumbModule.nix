#
# XXX: this is a nice hack
# by exporting the plain attrset as a module, we get to:
# - have a simple uncluttered config.nix that we can edit (and that a noob could edit)
# - not have to import the config everywhere, it's just there as a module
# - this is fine for very basic configuration where we don't need to document too much
#
# example:
#
#   modules = [
#     (nut.lib.mkDumbModule {
#       name = "dumb";
#       attrset = import ./config.nix;
#     })
#     # dumb.* will be available everywhere without importing.
#   ];
#

{ name, attrset }:
{ lib, ... }:
{
  options.${name} = lib.mapAttrs (
    _: value:
    lib.mkOption {
      type = lib.types.anything;
      default = value;
    }
  ) attrset;
}
