# generated by zon2nix (https://github.com/nix-community/zon2nix)

{ linkFarm, fetchzip }:

linkFarm "zig-packages" [
  {
    name = "1220687c8c47a48ba285d26a05600f8700d37fc637e223ced3aa8324f3650bf52242";
    path = fetchzip {
      url = "https://codeberg.org/ifreund/zig-wayland/archive/v0.2.0.tar.gz";
      hash = "sha256-dvit+yvc0MnipqWjxJdfIsA6fJaJZOaIpx4w4woCxbE=";
    };
  }
  {
    name = "12209db20ce873af176138b76632931def33a10539387cba745db72933c43d274d56";
    path = fetchzip {
      url = "https://codeberg.org/ifreund/zig-pixman/archive/v0.2.0.tar.gz";
      hash = "sha256-zcfZEMnipWDPuptl9UN0PoaJDjy2EHc7Wwi4GQq3hkY=";
    };
  }
  {
    name = "1220aeb3317e16c38583839961c9d695fa60d23a3d506c8275fb0e8fa9849844f2f7";
    path = fetchzip {
      url = "https://codeberg.org/ifreund/zig-wlroots/archive/e486223799648d27e8b91c5fe0ea4c088b74b707.tar.gz";
      hash = "sha256-quz2BfJXgw0kTwEF1ctllhoBNQ3AYeDSvqyDjicdSiM=";
    };
  }
  {
    name = "1220c90b2228d65fd8427a837d31b0add83e9fade1dcfa539bb56fd06f1f8461605f";
    path = fetchzip {
      url = "https://codeberg.org/ifreund/zig-xkbcommon/archive/v0.2.0.tar.gz";
      hash = "sha256-T+EZiStBfmxFUjaX05WhYkFJ8tRok/UQtpc9QY9NxZk=";
    };
  }
]
