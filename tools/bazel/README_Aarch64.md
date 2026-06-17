# Bazel on AArch64 (Marvell Prestera) and host setup

This document describes how **ARM64 target builds** are wired for Bazel in this tree, what changed on the AArch64 path compared to a plain `x86_64` host build, and how to install common host packages (including cross-compilers when you build **for** `aarch64` **from** `x86_64`).

## One-time host packages (`install_deps`)

Host package installation is **not** a Bazel target. Run the script from the top of the **sonic-buildimage** checkout (the directory that contains `MODULE.bazel`):

```bash
bash tools/bazel/install_deps.bash --help
```

Typical flows:

- **Same architecture as the Bazel target** (e.g. native `x86_64` host building default `x86_64` targets, or an `aarch64` machine building with `--config=aarch64-native`):

  ```bash
  bash tools/bazel/install_deps.bash --yes
  ```

- **`x86_64` workstation building AArch64 images** (Marvell Prestera, `--config=marvell-prestera`): pass **`aarch64`** so the script adds the Debian/Ubuntu cross toolchain packages (`gcc-aarch64-linux-gnu`, `g++-aarch64-linux-gnu`):

  ```bash
  bash tools/bazel/install_deps.bash --yes aarch64
  ```

Optional **`--with-rust`** installs distro `rustc` / `cargo` on your `PATH`. That is **not required** for `bazel build`: Rust actions use **rules_rust**'s downloaded toolchain. Use `--with-rust` only if you want a system Rust for shells or non-Bazel work; for a current stable toolchain, [rustup](https://rustup.rs/) is usually a better choice.

The script only automates **apt** on Debian/Ubuntu; other distributions print a package hint list.

The script installs **`bazel-bootstrap`** (Bazel from the Debian/Ubuntu universe repository) as part of the package list.

## Running compilation

All commands below are run from the **sonic-buildimage** root (where `MODULE.bazel` lives).

### Generic AArch64 (`--config=aarch64-native`)

Use **`--config=aarch64-native`** when you want the **ARM64 SONiC platform** (`//:linux_aarch64_sonic` in root `BUILD.bazel`) and the same **`CC=gcc` / `CXX=g++`** defaults as the Marvell config, **without** selecting Marvell's prebuilt **`@mrvllibsai`** SAI.

- **On an `x86_64` host** cross-compiling for AArch64, install host packages (including the cross toolchain) first:

  ```bash
  bash tools/bazel/install_deps.bash --yes aarch64
  ```

- **On a native `aarch64` machine**, the default `install_deps` run is enough for same-arch builds:

  ```bash
  bash tools/bazel/install_deps.bash --yes
  ```

**Example** (base Bookworm image for arm64; no Marvell-specific SAI):

```bash
bazel build --config=aarch64-native //dockers/docker-base-bookworm:docker-base-bookworm
```

To **load** that image into the local Docker daemon (requires Docker):

```bash
bazel build --config=aarch64-native //dockers/docker-base-bookworm:load
```

Many C/C++ or Python targets that link **SAI** still need an explicit ASIC configuration: **sonic-build-infra** defaults **`asic_manufacturer`** to **`_incompatible`** until you set it. For generic AArch64 work you often combine **`aarch64-native`** with another vendor flag from `.bazelrc`, for example the **virtual switch** stack:

```bash
bazel build --config=aarch64-native --config=vs <your-target>
```

Replace `<your-target>` with the Bazel label you need (for example a target under `@sonic_swss//…` or another included module).

### Marvell Prestera (`--config=marvell-prestera`)

Use **`--config=marvell-prestera`** when you are building **Marvell Prestera arm64** artifacts: it sets **`asic_manufacturer=marvell-prestera`**, **`sai=@mrvllibsai//:sai`**, **`--platforms=//:linux_aarch64_sonic`**, and the same **`CC`/`CXX`** defaults as **`aarch64-native`**.

From **`x86_64`**, install cross packages first:

```bash
bash tools/bazel/install_deps.bash --yes aarch64
```

**Example** (Prestera `syncd` OCI image, then load into Docker):

```bash
bazel build --config=marvell-prestera \
  //platform/marvell-prestera/docker-syncd-mrvl-prestera:docker-syncd-mrvl-prestera

bazel build --config=marvell-prestera \
  //platform/marvell-prestera/docker-syncd-mrvl-prestera:load
```

The **`:load`** target uses **`oci_load`** and talks to your Docker daemon; the **`docker-syncd-mrvl-prestera`** target builds the image tarball only.

## What is different for AArch64 / Marvell Prestera

### Bazel platforms and `.bazelrc` configs

Root `BUILD.bazel` defines **`//:linux_aarch64_sonic`**, a Bazel platform with Linux + `aarch64`, used whenever the build should target that CPU.

`.bazelrc` adds two configs that matter for AArch64 (see **[Running compilation](#running-compilation)** for how to invoke them):

| Config | Purpose |
|--------|---------|
| **`common:marvell-prestera`** | Marvell ASIC, prebuilt **`@mrvllibsai`** SAI (`platform/marvell-prestera/prestera.MODULE.bazel`), and **`--platforms=//:linux_aarch64_sonic`**. Also sets **`CC=gcc`** and **`CXX=g++`** in the action environment so Python sdist builds (e.g. under aspect_rules_py) pick a predictable compiler on minimal ARM64 images where the default might otherwise be clang or unset. |
| **`common:aarch64-native`** | Same **`linux_aarch64_sonic`** platform and **`CC`/`CXX`** defaults, without switching SAI to Marvell; useful for native AArch64 host builds that still use the hermetic toolchain layout. |

### sonic-build-infra: host tool wrappers under AArch64

When the **exec** platform is AArch64, **sonic-build-infra** selects wrapper scripts under:

`src/sonic-build-infra/toolchains/gcc/host_exec_linux_aarch64/wrappers/`

Those wrappers (`gcc`, `g++`, `ld`, `ar`, etc.) use **`#!/bin/bash`** as the shebang so the interpreter path does not depend on a minimal **`PATH`** inside Bazel's process-wrapper sandbox. Using **`#!/usr/bin/env bash`** there could fail with `env: 'bash': No such file or directory` during link steps (exit **127**) because `env` looks up `bash` by name on **`PATH`**.

### Marvell SAI binary

`platform/marvell-prestera/prestera.MODULE.bazel` fetches the **`mrvllibsai`** Debian package for **arm64**, extracts it, and exposes it as **`@mrvllibsai//:sai`**, which `--config=marvell-prestera` passes into **sonic-build-infra** via **`--@sonic_build_infra//:sai=@mrvllibsai//:sai`**.

## Related paths

| Path | Role |
|------|------|
| `tools/bazel/install_deps.bash` | Host `apt` helper (run with `bash`, not `bazel run`). |
| `.bazelrc` | `marvell-prestera` and `aarch64-native` configs. |
| `BUILD.bazel` (repo root) | `linux_aarch64_sonic` platform and `target_linux_aarch64` config_setting. |
| `platform/marvell-prestera/` | Prestera Bazel module, `mrvllibsai`, and `docker-syncd-mrvl-prestera` OCI targets. |
| `src/sonic-build-infra/toolchains/gcc/host_exec_linux_aarch64/` | AArch64 host-exec GCC/ld wrapper scripts. |

## Building for Marvell Prestera from the repo root

All commands below are run from the **sonic-buildimage** root (where `MODULE.bazel` lives).

### One-time host setup

**x86_64 host cross-compiling for arm64:**

```bash
bash tools/bazel/install_deps.bash --yes aarch64
```

**Native arm64 host:**

```bash
bash tools/bazel/install_deps.bash --yes
```

### Build targets

**Marvell Prestera syncd OCI image:**

```bash
bazel build --config=marvell-prestera \
  //platform/marvell-prestera/docker-syncd-mrvl-prestera:docker-syncd-mrvl-prestera
```

**Load it into the local Docker daemon:**

```bash
bazel build --config=marvell-prestera \
  //platform/marvell-prestera/docker-syncd-mrvl-prestera:load
```

**Base Bookworm arm64 image:**

```bash
bazel build --config=marvell-prestera \
  //dockers/docker-base-bookworm:docker-base-bookworm
```

**Any submodule target (e.g. libteam):**

```bash
bazel build --config=marvell-prestera @libteam//:libteam-utils_pkg
```

### What `--config=marvell-prestera` sets

| Flag | Value |
|------|-------|
| `--@sonic_build_infra//:asic_manufacturer` | `marvell-prestera` |
| `--@sonic_build_infra//:sai` | `@mrvllibsai//:sai` |
| `--platforms` | `//:linux_aarch64_sonic` |
| `--action_env=CC` | `gcc` |
| `--action_env=CXX` | `g++` |

### Useful flags

| Flag | Purpose |
|------|---------|
| `-j 8` | Limit parallelism (useful on low-RAM machines) |
| `--verbose_failures` | Show full command on build failure |
| `--sandbox_debug` | Keep sandbox on failure for debugging |
| `--output_base=/tmp/bazel-out` | Move output off a slow filesystem |

Example with extra flags:

```bash
bazel build --config=marvell-prestera \
  --verbose_failures \
  -j 8 \
  //platform/marvell-prestera/docker-syncd-mrvl-prestera:load
```

### Query available targets

```bash
# List all targets under marvell-prestera
bazel query //platform/marvell-prestera/...

# List all OCI images in the tree
bazel query 'kind(oci_image, //...)'
```
