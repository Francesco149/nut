{
  imports,
  user,
  mkHomeDir,
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${user} = {
      home.username = user;
      home.homeDirectory = mkHomeDir user;
      inherit imports;
    };
  };
}
