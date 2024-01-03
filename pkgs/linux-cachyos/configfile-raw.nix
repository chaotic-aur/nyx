{ cachyConfig
, fetchFromGitHub
, fetchurl
, lib
, stdenv
, flex
, bison
, perl
}:
let
  inherit (cachyConfig.versions.linux) version;
  major = lib.versions.pad 2 version;

  patches-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "kernel-patches";
    inherit (cachyConfig.versions.patches) rev hash;
  };

  config-src = fetchFromGitHub {
    owner = "CachyOS";
    repo = "linux-cachyos";
    inherit (cachyConfig.versions.config) rev hash;
  };

  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v6.x/linux-${
      if version == "${major}.0" then major else version
    }.tar.xz";
    inherit (cachyConfig.versions.linux) hash;
  };

  schedPatches =
    if cachyConfig.cpuSched == "eevdf" then
      [ ]
    else if cachyConfig.cpuSched == "cachyos" || cachyConfig.cpuSched == "hardened" then
      [ "${patches-src}/${major}/sched/0001-bore-cachy.patch" ]
    else if cachyConfig.cpuSched == "sched-ext" then
      [
        "${patches-src}/${major}/sched/0001-sched-ext.patch"
        "${patches-src}/${major}/sched/0001-bore-cachy-ext.patch"
      ]
    else throw "Unsupported cachyos _cpu_sched=${toString cachyConfig.cpuSched}";

  patches =
    [ "${patches-src}/${major}/all/0001-cachyos-base-all.patch" ]
    ++ schedPatches
    ++ lib.optional (cachyConfig.cpuSched == "hardened") "${patches-src}/${major}/misc/0001-hardened.patch"
    ++ lib.optional cachyConfig.withBCacheFS "${patches-src}/${major}/misc/0001-bcachefs.patch"
    ++ [ ./0001-Add-extra-version-CachyOS.patch ];

  # There are some configurations set by the PKGBUILD
  pkgbuildConfig = with cachyConfig;
    basicCachyConfig
    ++ cpuSchedConfig
    ++ [
      # _nr_cpus, defaults to empty, which later set this
      "--set-val NR_CPUS 320"

      # _per_gov, defaults to empty [but PERSONAL CHANGE to "y"]
      "-d CPU_FREQ_DEFAULT_GOV_SCHEDUTIL"
      "-e CPU_FREQ_DEFAULT_GOV_PERFORMANCE"

      # _tcp_bbr3, defaults to "y"
      "-m TCP_CONG_CUBIC"
      "-d DEFAULT_CUBIC"
      "-e TCP_CONG_BBR"
      "-e DEFAULT_BBR"
      "--set-str DEFAULT_TCP_CONG bbr"
      "-m NET_SCH_FQ_CODEL"
      "-e NET_SCH_FQ"
      "-d DEFAULT_FQ_CODEL"
      "-e DEFAULT_FQ"
      "--set-str DEFAULT_NET_SCH fq"
    ]
    ++ ltoConfig
    ++ ticksHzConfig
    ++ tickRateConfig
    ++ preemptConfig
    ++ [
      # _cc_harder, defaults to "y"
      "-d CC_OPTIMIZE_FOR_PERFORMANCE"
      "-e CC_OPTIMIZE_FOR_PERFORMANCE_O3"

      # _lru_config, defaults to "standard"
      "-e LRU_GEN"
      "-e LRU_GEN_ENABLED"
      "-d LRU_GEN_STATS"

      # _vma_config, defaults to "standard"
      "-e PER_VMA_LOCK"
      "-d PER_VMA_LOCK_STATS"
    ]
    ++ hugePagesConfig
    ++ damonConfig
    ++ disableDebug

    #_use_auto_optimization, defaults to "y" [but GENERIC to ""]
  ;

  # _cachy_config, defaults to "y"
  basicCachyConfig =
    lib.optional cachyConfig.basicCachy "-e CACHY";

  # _cpusched, defaults to "cachyos"
  cpuSchedConfig =
    if cachyConfig.cpuSched == "eevdf" then
      [ ]
    else if cachyConfig.cpuSched == "cachyos" || cachyConfig.cpuSched == "hardened" then
      [ "-e SCHED_BORE" ]
    else if cachyConfig.cpuSched == "sched-ext" then
      [ "-e SCHED_BORE" "-e SCHED_CLASS_EXT" ]
    else throw "Unsupported cachyos scheduler";

  # _HZ_ticks, defaults to "500"
  ticksHzConfig =
    if cachyConfig.ticksHz == 300 then
      [ "-e HZ_300" "--set-val HZ 300" ]
    else [
      "-d HZ_300"
      "--set-val HZ ${toString cachyConfig.ticksHz}"
      "-e HZ_${toString cachyConfig.ticksHz}"
    ];

  # _use_llvm_lto, defaults to "none"
  ltoConfig =
    if cachyConfig.useLTO == "thin" then
      [ "-e LTO" "-e LTO_CLANG" "-e ARCH_SUPPORTS_LTO_CLANG" "-e ARCH_SUPPORTS_LTO_CLANG_THIN" "-d LTO_NONE" "-e HAS_LTO_CLANG" "-d LTO_CLANG_FULL" "-e LTO_CLANG_THIN" "-e HAVE_GCC_PLUGINS" ]
    else if cachyConfig.useLTO == "full" then
      [ "-e LTO" "-e LTO_CLANG" "-e ARCH_SUPPORTS_LTO_CLANG" "-e ARCH_SUPPORTS_LTO_CLANG_THIN" "-d LTO_NONE" "-e HAS_LTO_CLANG" "-e LTO_CLANG_FULL" "-d LTO_CLANG_THIN" "-e HAVE_GCC_PLUGINS" ]
    else if cachyConfig.useLTO == "none" then
      [ ]
    else throw "Unsupported cachyos _use_llvm_lto";

  # _tickrate defaults to "full"
  tickRateConfig =
    if cachyConfig.tickRate == "idle" then
      [ "-d HZ_PERIODIC" "-d NO_HZ_FULL" "-e NO_HZ_IDLE" "-e NO_HZ" "-e NO_HZ_COMMON" ]
    else if cachyConfig.tickRate == "full" then
      [ "-d HZ_PERIODIC" "-d NO_HZ_IDLE" "-d CONTEXT_TRACKING_FORCE" "-e NO_HZ_FULL_NODEF" "-e NO_HZ_FULL" "-e NO_HZ" "-e NO_HZ_COMMON" "-e CONTEXT_TRACKING" ]
    else throw "Unsupported cachyos _tickrate";

  # _preempt, defaults to "full"
  preemptConfig =
    if cachyConfig.preempt == "full" then
      [ "-e PREEMPT_BUILD" "-d PREEMPT_NONE" "-d PREEMPT_VOLUNTARY" "-e PREEMPT" "-e PREEMPT_COUNT" "-e PREEMPTION" "-e PREEMPT_DYNAMIC" ]
    else if cachyConfig.preempt == "server" then
      [ "-e PREEMPT_NONE_BUILD" "-e PREEMPT_NONE" "-d PREEMPT_VOLUNTARY" "-d PREEMPT" "-d PREEMPTION" "-d PREEMPT_DYNAMIC" ]
    else throw "Unsupported cachyos _preempt";

  # _hugepage, defaults to "always"
  hugePagesConfig =
    if cachyConfig.hugePages == "always" then
      [ "-d TRANSPARENT_HUGEPAGE_MADVISE" "-e TRANSPARENT_HUGEPAGE_ALWAYS" ]
    else if cachyConfig.hugePages == "madvise" then
      [ "-d TRANSPARENT_HUGEPAGE_ALWAYS" "-e TRANSPARENT_HUGEPAGE_MADVISE" ]
    else throw "Unsupported cachyos _hugepage";

  # _damon, defaults to empty
  damonConfig =
    lib.optionals cachyConfig.withDAMON [
      "-e DAMON"
      "-e DAMON_VADDR"
      "-e DAMON_DBGFS"
      "-e DAMON_SYSFS"
      "-e DAMON_PADDR"
      "-e DAMON_RECLAIM"
      "-e DAMON_LRU_SORT"
    ];

  # https://github.com/CachyOS/linux-cachyos/issues/187
  disableDebug =
    lib.optionals (cachyConfig.withoutDebug && cachyConfig.cpuSched != "sched-ext") [
      "-d DEBUG_INFO"
      "-d DEBUG_INFO_BTF"
      "-d DEBUG_INFO_DWARF4"
      "-d DEBUG_INFO_DWARF5"
      "-d PAHOLE_HAS_SPLIT_BTF"
      "-d DEBUG_INFO_BTF_MODULES"
      "-d SLUB_DEBUG"
      "-d PM_DEBUG"
      "-d PM_ADVANCED_DEBUG"
      "-d PM_SLEEP_DEBUG"
      "-d ACPI_DEBUG"
      "-d SCHED_DEBUG"
      "-d LATENCYTOP"
      "-d DEBUG_PREEMPT"
    ];

  makeFlags =
    if cachyConfig.useLTO != "none" then
      "LLVM=1 LLVM_IAS=1"
    else "";
in
stdenv.mkDerivation {
  inherit src patches;
  name = "linux-cachyos-config";
  nativeBuildInputs = [ flex bison perl ];

  preparePhase = ''
    cp "${config-src}/${cachyConfig.taste}/config" ".config"
  '';

  buildPhase = ''
    make ${makeFlags} defconfig
    cp "${config-src}/${cachyConfig.taste}/config" ".config"
    patchShebangs scripts/config
    scripts/config ${lib.concatStringsSep " " pkgbuildConfig}
  '';

  installPhase = ''
    cp .config $out
  '';

  passthru.kernelPatches = patches;
}
