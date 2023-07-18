{ final, flakes, nyxUtils, prev, ... }:

# yuzu doesn't seem to recognize our mbedtls_2
let
  dynarmic = final.fetchFromGitHub {
    owner = "merryhime";
    repo = "dynarmic";
    rev = "6.4.8";
    hash = "sha256-lsfwR+ydtn3LWWh0Jfb8+2qJqnRbjoTM18Wb1lfX/8w=";
  };
  sirit = final.fetchFromGitHub {
    owner = "ReinUsesLisp";
    repo = "sirit";
    rev = "d7ad93a88864bda94e282e95028f90b5784e4d20";
    hash = "sha256-WDZivcYYe1qKV6IVsDPCHpAxKc+FWsSDlVw+pekCgmI=";
  };
  xbyak = final.fetchFromGitHub {
    owner = "herumi";
    repo = "xbyak";
    rev = "v6.70";
    hash = "sha256-y2GOR6yKIx7W5peFf5FzXlF2iJUfDE/RnMWjO/h/Ruk=";
  };
  tzdataVer = "220816";
  tzdata = final.fetchurl {
    url = "https://github.com/lat9nq/tzdb_to_nx/releases/download/${tzdataVer}/${tzdataVer}.zip";
    hash = "sha256-yv8ykEYPu9upeXovei0u16iqQ7NasH6873KnQy4+KwI=";
  };
  vma = final.fetchurl {
    url = "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/raw/0aa3989b8f382f185fdf646cc83a1d16fa31d6ab/include/vk_mem_alloc.h";
    hash = "sha256-5lfqRtC6yWGU1cDgH16crSm/Lpy8OEst6FsIwf5VVxo=";
  };

  inherit (final.vulkanPackages_latest) glslang vulkan-headers vulkan-loader spirv-headers;
  base = prev.yuzu-early-access.override
    { inherit glslang vulkan-headers vulkan-loader; };
in
base.overrideAttrs (pa: rec {
  src = flakes.yuzu-ea-git-src;
  version = nyxUtils.gitToVersion src;

  # We need to have these headers ahead, otherwise they cause an ordering issue in CMAKE_INCLUDE_PATH,
  # where qtbase propagated input appears first.
  nativeBuildInputs = [ vulkan-headers glslang spirv-headers ] ++ pa.nativeBuildInputs;

  cmakeFlags = pa.cmakeFlags ++ [
    "-DSIRIT_USE_SYSTEM_SPIRV_HEADERS=ON"
  ];

  postPatch = (pa.postPatch or "") + ''
    rm -r externals/{cpp-httplib,dynarmic,mbedtls,sirit,xbyak}
    cp --no-preserve=mode -r ${final.mbedtls_2.src} externals/mbedtls
    ln -s ${final.httplib.src} externals/cpp-httplib
    ln -s ${dynarmic} externals/dynarmic
    ln -s ${sirit} externals/sirit
    ln -s ${xbyak} externals/xbyak
    mkdir -p externals/vma/VulkanMemoryAllocator/include
    ln -s ${vma} externals/vma/VulkanMemoryAllocator/include/vk_mem_alloc.h
  '';

  preConfigure = ''
    pushd externals/mbedtls
    perl scripts/config.pl set MBEDTLS_THREADING_C
    perl scripts/config.pl set MBEDTLS_THREADING_PTHREAD
    perl scripts/config.pl set MBEDTLS_CMAC_C
    popd

    _ver=$(grep -Po '(?<=for early-access )([^.]*)' "${src}/README.md")

    # See https://github.com/NixOS/nixpkgs/issues/114044, setting this through cmakeFlags does not work.
    # These will fix version "formatting"
    cmakeFlagsArray+=(
      "-DTITLE_BAR_FORMAT_IDLE=yuzu Early Access EA-$_ver"
      "-DTITLE_BAR_FORMAT_RUNNING=yuzu Early Access EA-$_ver | {3}"
    )

    cmakeBuildDir=''${cmakeBuildDir:=build}
   
    mkdir -p "$cmakeBuildDir/externals/nx_tzdb"
    ln -s ${tzdata} "$cmakeBuildDir/externals/nx_tzdb/${tzdataVer}.zip"
  '';

  # Shows released date in version
  env.SOURCE_DATE_EPOCH = src.lastModified;

  # Right now crypto tests don't pass
  doCheck = false;

  # We bump it with flakes
  passthru = pa.passthru // { updateScript = null; };
})
