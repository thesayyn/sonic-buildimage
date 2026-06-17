"""Hermetic libdbus-c++-bin tools for genrules (dbusxx-xml2cpp).

The Debian .deb must match the CPU of the machine running Bazel: amd64 .deb on
x86_64 hosts, arm64 .deb on AArch64 hosts. Target platform (e.g. Prestera
`linux_aarch64_sonic`) is independent of this host tool choice.
"""

def _libdbus_bin_repo(rctx):
    arch = rctx.os.arch
    if arch in ("aarch64", "arm64"):
        url = "https://snapshot.debian.org/archive/debian/20240630T000000Z/pool/main/d/dbus-c++/libdbus-c++-bin_0.9.0-11_arm64.deb"
        sha256 = "8da3997fe6abb029ab586c3f59b370904ed73cf9edbf13226dc77eda514c870e"
    else:
        url = "https://snapshot.debian.org/archive/debian/20240630T000000Z/pool/main/d/dbus-c++/libdbus-c++-bin_0.9.0-11_amd64.deb"
        sha256 = "8682fad507dc508219f5b24a7f3b922b9ae527b8f16436dfc4559035e852cdd5"

    rctx.download(url = url, output = "pkg.deb", sha256 = sha256)
    ar = rctx.which("ar")
    if not ar:
        fail("libdbus_bin_repo: `ar` not found on PATH (needed to unpack .deb)")
    res = rctx.execute([ar, "x", "pkg.deb", "data.tar.xz"])
    if res.return_code != 0:
        fail("libdbus_bin_repo: ar failed: " + res.stderr)
    rctx.delete("pkg.deb")
    tar = rctx.which("tar")
    if not tar:
        fail("libdbus_bin_repo: `tar` not found on PATH (needed to unpack data.tar.xz)")
    res = rctx.execute([tar, "xf", "data.tar.xz"])
    if res.return_code != 0:
        fail("libdbus_bin_repo: tar failed: " + res.stderr)
    rctx.delete("data.tar.xz")
    rctx.file("BUILD.bazel", rctx.read(rctx.path(Label("//:libdbus_bin.BUILD"))))

libdbus_bin = repository_rule(
    implementation = _libdbus_bin_repo,
    attrs = {},
)
