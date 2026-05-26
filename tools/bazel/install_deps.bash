#!/usr/bin/env bash
# Install host packages useful for SONiC Bazel builds, based on host CPU and the
# Bazel target CPU you plan to build for (e.g. marvell-prestera aarch64 images from
# an x86_64 workstation).
#
# This is intentionally not a Bazel target: run it directly with bash (or make it
# executable and invoke ./tools/bazel/install_deps.bash from the sonic-buildimage tree).
# AArch64 Bazel setup and Marvell Prestera usage: tools/bazel/README_Aarch64.md
set -u

DRY_RUN=0
ASSUME_YES=0
WITH_RUST="${WITH_RUST:-0}"
TARGET_ARCH=""

usage() {
  cat <<'EOF'
Usage: bash tools/bazel/install_deps.bash [options] [target_arch]

  (from the top of the sonic-buildimage checkout; not a bazel build/run target)

  target_arch   aarch64 | x86_64 | auto (default: auto = same as host)

Options:
  --dry-run     Print apt command only.
  --yes, -y     Pass -y to apt-get install (non-interactive).
  --with-rust   Also install rustc + cargo on PATH (distro packages; optional for Bazel).

Examples:
  bash tools/bazel/install_deps.bash
  bash tools/bazel/install_deps.bash aarch64
  bash tools/bazel/install_deps.bash --yes x86_64
  bash tools/bazel/install_deps.bash --yes --with-rust

Notes:
  - Bazel builds use rules_rust's downloaded rustc; you do not need system rustc for `bazel build`.
  - Use --with-rust only if you want `rustc` / `cargo` in your shell (e.g. for non-Bazel Rust work).
  - For a current stable toolchain, prefer https://rustup.rs/ instead of distro rustc.
  - Only Debian/Ubuntu (apt) is automated; other distros print a package hint list.
  - Installs bazel-bootstrap (Bazel from the Ubuntu/Debian universe repository).
EOF
}

normalize_cpu() {
  case "$1" in
    aarch64 | arm64 | armv8l) echo aarch64 ;;
    x86_64 | amd64) echo x86_64 ;;
    *) echo "$1" ;;
  esac
}

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes | -y) ASSUME_YES=1; shift ;;
    --with-rust) WITH_RUST=1; shift ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "${TARGET_ARCH}" ]]; then
        echo "unexpected extra argument: $1" >&2
        usage >&2
        exit 2
      fi
      TARGET_ARCH="$1"
      shift
      ;;
  esac
done

if ! command -v uname >/dev/null 2>&1; then
  echo "uname is required" >&2
  exit 1
fi

HOST_RAW="$(uname -m)"
HOST="$(normalize_cpu "${HOST_RAW}")"

if [[ -z "${TARGET_ARCH}" || "${TARGET_ARCH}" == auto ]]; then
  TARGET="${HOST}"
else
  TARGET="$(normalize_cpu "${TARGET_ARCH}")"
fi

if [[ "${TARGET}" != aarch64 && "${TARGET}" != x86_64 ]]; then
  echo "Unsupported target_arch '${TARGET_ARCH}' (normalized: ${TARGET}). Use aarch64 or x86_64." >&2
  exit 2
fi

echo "host_arch=${HOST} (from uname -m=${HOST_RAW}) target_arch=${TARGET}" >&2

# Baseline packages for Bazel + Python sdists + common native deps.
PKGS=(
  bazel-bootstrap
  bash
  build-essential
  ca-certificates
  curl
  git
  pkg-config
  python3
  python3-venv
  tar
  unzip
  wget
  zip
  zlib1g-dev
  libssl-dev
)

# Headers often needed when wheels fall back to sdists (lxml, etc.).
PKGS+=(
  libxml2-dev
  libxslt1-dev
)

# Optional but avoids hosts that only have gcc as /usr/bin/gcc while some tooling probes clang.
PKGS+=(clang)

if [[ "${WITH_RUST}" == 1 ]]; then
  PKGS+=(
    rustc
    cargo
  )
fi

if [[ "${HOST}" == x86_64 && "${TARGET}" == aarch64 ]]; then
  PKGS+=(
    gcc-aarch64-linux-gnu
    g++-aarch64-linux-gnu
  )
elif [[ "${HOST}" == aarch64 && "${TARGET}" == x86_64 ]]; then
  echo "Note: cross-building for x86_64 from aarch64 is uncommon; install your distro's x86_64 cross toolchain manually if needed." >&2
fi

if [[ -f /etc/debian_version ]] && command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  if [[ "${WITH_RUST}" == 1 ]]; then
    echo "Installing distro rustc/cargo for PATH; Bazel still uses rules_rust's toolchain. For latest stable, use https://rustup.rs/ instead." >&2
  fi
  APT=(sudo apt-get install)
  if [[ "${ASSUME_YES}" == 1 ]]; then
    APT+=(--yes)
  fi
  APT+=("${PKGS[@]}")
  if [[ "${DRY_RUN}" == 1 ]]; then
    printf '%q ' "${APT[@]}"
    echo
    exit 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required for apt-get on this host" >&2
    exit 1
  fi
  exec "${APT[@]}"
fi

echo "Non-Debian or apt-less system: install the following (names may differ):" >&2
printf ' - %s\n' "${PKGS[@]}" >&2
exit 0
