{ flakes, nyxUtils, prev, mangohud32, ... }:

(prev.mangohud.override { inherit mangohud32; }).overrideAttrs (prevAttrs: rec {
  version = nyxUtils.gitToVersion src;
  src = flakes.mangohud-git-src;
  patches = [ ./preload-nix-workaround.patch ] ++
    (nyxUtils.removeByBaseName "preload-nix-workaround.patch" prevAttrs.patches);
  # We bump it with flakes
  passthru = prevAttrs.passthru // { updateScript = null; };
})
