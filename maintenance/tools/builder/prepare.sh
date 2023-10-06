# Derivate temporary paths
TMPDIR="${NYX_TEMP:-${TMPDIR}}"
NIX_BUILD_TOP="${NYX_TEMP:-${NIX_BUILD_TOP}}"
TMP="${NYX_TEMP:-${TMP}}"
TEMP="${NYX_TEMP:-${TEMP}}"
TEMPDIR="${NYX_TEMP:-${TEMPDIR}}"

# Options (2)
NYX_FLAGS="${NYX_FLAGS:---accept-flake-config --no-link}"
NYX_WD="${NYX_WD:-$(mktemp -d)}"

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[1;36m'
W='\033[0m'

# Create empty logs and artifacts
cd "$NYX_WD"
touch push.txt errors.txt success.txt failures.txt cached.txt upstream.txt eval-failures.txt
echo "{" > new-failures.nix

# Echo helpers
function echo_warning() {
  echo -ne "${Y}WARNING:${W} "
  echo "$@"
}

function echo_error() {
  echo -ne "${R}ERROR:${W} " 1>&2
  echo "$@" 1>&2
}

# Warn if we don't have automated cachix
if [ -z "$CACHIX_AUTH_TOKEN" ] && [ -z "$CACHIX_SIGNING_KEY" ]; then
  echo_warning "No key for cachix -- building anyway."
fi

# Check if $1 is in the cache
function cached() {
  set -e
  nix path-info "$2" --store "$1" >/dev/null 2>/dev/null
}

# Creates list of what to build when only building what changed
if [ -n "${NYX_CHANGED_ONLY:-}" ]; then
  _DIFF=$(nix build --no-link --print-out-paths --impure --expr "(builtins.getFlake \"$NYX_SOURCE\").devShells.${NYX_TARGET}-linux.comparer.passthru.any \"$NYX_CHANGED_ONLY\"" || exit 13)

  ln -s "$_DIFF" filter.txt
fi

# Helper to zip-merge _ALL_OUT_KEYS and _ALL_OUT_PATHS
function zip_path() {
  for (( i=0; i<${#_ALL_OUT_KEYS[*]}; ++i)); do
    echo "${_ALL_OUT_KEYS[$i]}" "${_ALL_OUT_PATHS[$i]}"
  done
}

# Per-derivation build function
function build() {
  _WHAT="${1:- アンノーン}"
  _MAIN_OUT_PATH="${2:-/dev/null}"
  _FULL_TARGETS=("${_ALL_OUT_KEYS[@]/#/$NYX_SOURCE\#_dev.packages.${NYX_TARGET}.}")
  echo -n "* $_WHAT..."
  # If NYX_CHANGED_ONLY is set, only build changed derivations
  if [ -f filter.txt ] && ! grep -Pq "^$_WHAT\$" filter.txt; then
    echo -e "${Y} SKIP${W}"
    return 0
  elif [ -z "${NYX_REFRESH:-}" ] && cached 'https://chaotic-nyx.cachix.org' "$_MAIN_OUT_PATH"; then
    echo "$_WHAT" >> cached.txt
    echo -e "${Y} CACHED${W}"
    zip_path >> full-pin.txt
    return 0
  elif cached 'https://cache.nixos.org' "$_MAIN_OUT_PATH"; then
    echo "$_WHAT" >> upstream.txt
    echo -e "${Y} CACHED-UPSTREAM${W}"
    return 0
  else
    (while true; do echo -ne "${C} BUILDING${W}\n* $_WHAT..." && sleep 120; done) &
    _KEEPALIVE=$!
    if \
      ( set -o pipefail;
        nix build --json $NYX_FLAGS "${_FULL_TARGETS[@]}" |\
          jq -r '.[].outputs[]' \
      ) 2>> errors.txt >> push.txt
    then
      echo "$_WHAT" >> success.txt
      kill $_KEEPALIVE
      echo -e "${G} OK${W}"
      zip_path | tee -a to-pin.txt >> full-pin.txt
      return 0
    else
      echo "$_WHAT" >> failures.txt
      echo "  \"$_WHAT\" = \"$_MAIN_OUT_PATH\";" >> new-failures.nix
      kill $_KEEPALIVE
      echo -e "${R} ERR${W}"
      return 1
    fi
  fi
}
