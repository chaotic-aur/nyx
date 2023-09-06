{ lib
, callPackage
, importJSON ? lib.trivial.importJSON
}:
{ nyxKey
, versionNyxPath
, versionLocalPath
, prev
, fetcher
, fetchLatestRev
, current ? importJSON versionLocalPath
, newInputs ? null
, preOverrides ? [ ]
, postOverrides ? [ ]
}:

let
  main = prevAttrs:
    let
      src = fetcher prevAttrs { inherit (current) rev hash; };

      hasCargo = (prevAttrs ? cargoDeps);

      updateScript = callPackage ./git-update.nix {
        inherit (prevAttrs) pname;
        inherit nyxKey hasCargo;
        versionPath = versionNyxPath;
        fetchLatestRev = fetchLatestRev src;
        gitUrl = src.gitRepoUrl;
      };

      common = {
        inherit (current) version;
        inherit src;
        passthru = (prevAttrs.passthru or { })
          // { inherit updateScript; };
      };

      whenCargo =
        lib.attrsets.optionalAttrs hasCargo {
          cargoDeps = prevAttrs.cargoDeps.overrideAttrs (_cargoPrevAttrs: {
            inherit (prevAttrs) src;
            outputHash = current.cargoHash;
          });
        };
    in
    common // whenCargo;
in
lib.lists.foldl
  (accu: accu.overrideAttrs)
  (if newInputs == null then prev else prev.override newInputs)
  (preOverrides ++ [ main ] ++ postOverrides)
