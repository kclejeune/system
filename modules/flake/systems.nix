{ lib, ... }:
{
  systems = lib.intersectLists (lib.platforms.linux ++ lib.platforms.darwin) (
    lib.platforms.x86_64 ++ lib.platforms.aarch64
  );
}
