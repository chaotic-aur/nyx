# Conventions:
# - Sort packages in alphabetic order.
# - If the recipe uses `override` or `overrideAttrs`, then use callOverride,
#   otherwise use `final`.
# - Composed names are separated with minus: `input-leap`
# - Versions/patches are suffixed with an underline: `mesa_git`, `libei_0_5`, `linux_hdr`
# - Use `inherit (final) nyxUtils` since someone might want to override our utils

# NOTE:
# - `*_next` packages will be removed once merged into nixpkgs-unstable.

{ flakes, selfOverlay }: final: prev:
let
  # Required to load version files.
  inherit (final.lib.trivial) importJSON;

  # Our utilities/helpers.
  nyxUtils = import ../shared/utils.nix { inherit (final) lib; nyxOverlay = selfOverlay; };
  inherit (nyxUtils) dropAttrsUpdateScript dropUpdateScript multiOverride multiOverrides overrideDescription;

  # Helps when calling .nix that will override packages.
  callOverride = path: attrs: import path ({ inherit final flakes nyxUtils prev gitOverride; } // attrs);

  # Helps when calling .nix that will override i686-packages.
  callOverride32 = path: attrs: import path ({
    inherit flakes nyxUtils gitOverride;
    final = final.pkgsi686Linux;
    prev = prev.pkgsi686Linux;
  } // attrs);

  # CachyOS repeating stuff.
  cachyVersions = importJSON ../pkgs/linux-cachyos/versions.json;

  # CachyOS repeating stuff.
  cachyZFS = _finalAttrs: prevAttrs:
    let
      zfs = prevAttrs.zfsUnstable.overrideAttrs (prevAttrs: {
        src =
          final.fetchFromGitHub {
            owner = "cachyos";
            repo = "zfs";
            inherit (cachyVersions.zfs) rev hash;
          };
        meta = prevAttrs.meta // { broken = false; };
        patches = [ ];
      });
    in
    {
      inherit zfs;
      zfsStable = zfs;
      zfsUnstable = zfs;
    };

  # Magic helper for _git packages.
  gitOverride = import ../shared/git-override.nix { inherit (final) lib callPackage; };
in
{
  inherit nyxUtils;

  nyx-generic-git-update = final.callPackage ../pkgs/nyx-generic-git-update { };

  alacritty_git = callOverride ../pkgs/alacritty-git { };

  ananicy-cpp-rules = final.callPackage ../pkgs/ananicy-cpp-rules { };

  applet-window-appmenu = final.libsForQt5.callPackage ../pkgs/applet-window-appmenu { };

  applet-window-title = final.callPackage ../pkgs/applet-window-title { };

  appmenu-gtk3-module = final.callPackage ../pkgs/appmenu-gtk3-module { };

  beautyline-icons = final.callPackage ../pkgs/beautyline-icons { };

  blurredwallpaper = final.callPackage ../pkgs/blurredwallpaper { };

  busybox_appletless = multiOverride
    prev.busybox
    { enableAppletSymlinks = false; }
    (overrideDescription (old: old + " (without applets' symlinks)"));

  bytecode-viewer_git = final.callPackage ../pkgs/bytecode-viewer-git { };

  discord-krisp = callOverride ../pkgs/discord-krisp { };

  dr460nized-kde-theme = final.callPackage ../pkgs/dr460nized-kde-theme { };

  droid-sans-mono-nerdfont = multiOverrides
    final.nerdfonts
    { fonts = [ "DroidSansMono" ]; }
    [
      dropUpdateScript
      (overrideDescription (_prevDesc: "Provides \"DroidSansM Nerd Font\" font family."))
    ];

  firedragon-unwrapped = final.callPackage ../pkgs/firedragon { };

  firedragon = final.wrapFirefox final.firedragon-unwrapped {
    inherit (final.firedragon-unwrapped) extraPrefsFiles extraPoliciesFiles;
    libName = "firedragon";
  };

  firefox-unwrapped_nightly = final.callPackage ../pkgs/firefox-nightly { };
  firefox_nightly = final.wrapFirefox final.firefox-unwrapped_nightly { };

  gamescope_git = callOverride ../pkgs/gamescope-git { };

  # Used by telegram-desktop_git
  glib_git = callOverride ../pkgs/glib-git { };
  glibmm_git = callOverride ../pkgs/glibmm-git { inherit (final) glib_git; };

  input-leap_git = callOverride ../pkgs/input-leap-git {
    inherit (final.libsForQt5.qt5) qttools;
  };

  latencyflex-vulkan = final.callPackage ../pkgs/latencyflex-vulkan { };

  linux_cachyos-configfile_raw = final.callPackage ../pkgs/linux-cachyos/configfile-raw.nix {
    inherit cachyVersions;
  };
  linux_cachyos-configfile_nix = final.callPackage ../pkgs/linux-cachyos/configfile-bake.nix {
    configfile = final.linux_cachyos-configfile_raw;
  };
  linux_cachyos = final.callPackage ../pkgs/linux-cachyos {
    inherit cachyVersions;
    cachyConfig =
      if final.system == "x86_64-linux" then
        import ../pkgs/linux-cachyos/config-x86_64-linux.nix
      else import ../pkgs/linux-cachyos/config-aarch64-linux.nix;
  };

  linuxPackages_cachyos = (dropAttrsUpdateScript
    ((final.linuxPackagesFor final.linux_cachyos).extend cachyZFS)
  ) // { _description = "Kernel modules for linux_cachyos"; };

  luxtorpeda = final.callPackage ../pkgs/luxtorpeda {
    luxtorpedaVersion = importJSON ../pkgs/luxtorpeda/version.json;
  };

  # You should not need "mangohud32_git" since it's embedded in "mangohud_git"
  mangohud_git = callOverride ../pkgs/mangohud-git { inherit (final) mangohud32_git; };
  mangohud32_git =
    if final.stdenv.hostPlatform.isLinux && final.stdenv.hostPlatform.isx86
    then
      callOverride32 ../pkgs/mangohud-git { inherit (final) mangohud32_git; }
    else throw "No mangohud32_git for non-x86";

  mesa_git = callOverride ../pkgs/mesa-git {
    gbmDriver = true;
  };
  mesa32_git =
    if final.stdenv.hostPlatform.isLinux && final.stdenv.hostPlatform.isx86
    then
      callOverride32 ../pkgs/mesa-git { }
    else throw "No mesa32_git for non-x86";

  mpv-vapoursynth = (final.wrapMpv
    (final.mpv-unwrapped.override { vapoursynthSupport = true; })
    {
      extraMakeWrapperArgs = [
        "--prefix"
        "LD_LIBRARY_PATH"
        ":"
        "${final.vapoursynth-mvtools}/lib/vapoursynth"
      ];
    }
  ).overrideAttrs (overrideDescription (old: old + " (includes vapoursynth)"));

  nix-flake-schemas_git = callOverride ../pkgs/nix-flake-schemas-git { };

  nordvpn = final.callPackage ../pkgs/nordvpn { };

  nss_git = callOverride ../pkgs/nss-git { };

  openmohaa = final.callPackage ../pkgs/openmohaa {
    openmohaaVersion = importJSON ../pkgs/openmohaa/version.json;
  };

  proton-ge-custom = final.callPackage ../pkgs/proton-ge-custom {
    protonGeTitle = "Proton-GE";
    protonGeVersions = importJSON ../pkgs/proton-ge-custom/versions.json;
  };

  river_git = callOverride ../pkgs/river-git { };

  sway-unwrapped_git = callOverride ../pkgs/sway-unwrapped-git { };
  sway_git = prev.sway.override {
    sway-unwrapped = final.sway-unwrapped_git;
  };

  swaylock-plugin_git = callOverride ../pkgs/swaylock-plugin-git { };

  telegram-desktop_git = callOverride ../pkgs/telegram-desktop-git { inherit (final) tg-owt_git glib_git glibmm_git; };
  tg-owt_git = callOverride ../pkgs/tg-owt-git { inherit (final) glib_git; };

  # You should not need "mangohud32_git" since it's embedded in "mangohud_git"
  vkshade_git = callOverride ../pkgs/vkshade-git { inherit (final) vkshade32_git; };
  vkshade32_git =
    if final.stdenv.hostPlatform.isLinux && final.stdenv.hostPlatform.isx86
    then
      callOverride32 ../pkgs/vkshade-git { inherit (final) vkshade32_git; }
    else throw "No vkshade32_git for non-x86";

  vulkanPackages_latest = callOverride ../pkgs/vulkan-versioned
    { vulkanVersions = importJSON ../pkgs/vulkan-versioned/latest.json; };

  waynergy_git = callOverride ../pkgs/waynergy-git { };

  wlroots_git = callOverride ../pkgs/wlroots-git { };

  yt-dlp_git = callOverride ../pkgs/yt-dlp-git { };

  yuzu-early-access_git = callOverride ../pkgs/yuzu-ea-git { };
}
