{ final
, flakes
, nyxUtils
, prev
, gbmDriver ? false
, gbmBackend ? "dri_git"
, meson ? final.meson
, mesaTestAttrs ? final
, ...
}:

nyxUtils.multiOverride prev.mesa { inherit meson; } (prevAttrs: {
  version = builtins.substring 0 (builtins.stringLength prevAttrs.version) flakes.mesa-git-src.rev;
  src = flakes.mesa-git-src;
  buildInputs = prevAttrs.buildInputs ++ (with final; [ libunwind lm_sensors ]);
  mesonFlags =
    builtins.map
      (builtins.replaceStrings [ "virtio-experimental" ] [ "virtio" ])
      prevAttrs.mesonFlags;
  patches =
    (nyxUtils.removeByBaseName
      "disk_cache-include-dri-driver-path-in-cache-key.patch"
      prevAttrs.patches
    ) ++ [
      ./disk_cache-include-dri-driver-path-in-cache-key.patch
      ./gbm-backend.patch
    ];
  # expose gbm backend and rename vendor (if necessary)
  outputs =
    if gbmDriver
    then prevAttrs.outputs ++ [ "gbm" ]
    else prevAttrs.outputs;
  postPatch =
    if gbmBackend != "dri_git" then prevAttrs.postPatch + ''
      sed -i"" 's/"dri_git"/"${gbmBackend}"/' src/gbm/backends/dri/gbm_dri.c src/gbm/main/backend.c
    '' else prevAttrs.postPatch;
  postInstall =
    if gbmDriver then prevAttrs.postInstall + ''
      mkdir -p $gbm/lib/gbm
      ln -s $out/lib/libgbm.so $gbm/lib/gbm/${gbmBackend}_gbm.so
    '' else prevAttrs.postInstall;
  passthru = prevAttrs.passthru // {
    inherit gbmBackend;
    tests.smoke-test = import ./test.nix
      {
        inherit (flakes) nixpkgs;
        chaotic = flakes.self;
      }
      mesaTestAttrs;
  };
})
