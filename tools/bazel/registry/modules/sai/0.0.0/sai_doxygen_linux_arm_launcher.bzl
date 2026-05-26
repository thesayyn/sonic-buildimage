"""rules_doxygen `linux-arm` helper (native AArch64 Linux hosts).

`doxygen_extension.configuration(version = "0.0.0", platform = "linux-arm")` calls
`ctx.which("doxygen")` during repository fetch; Bazel often runs that with a PATH
where `which("doxygen")` is None, which fails analysis before any build action runs.

Instead we install a tiny shell script as the `executable` for `linux-arm`. The
rules_doxygen repository rule copies this script into `linux/doxygen`. At
**build** time the script execs a system Doxygen if present (install e.g.
`doxygen` and `libclang1-14` on Debian/Ubuntu).
"""

def _sai_doxygen_linux_arm_launcher_impl(rctx):
    rctx.file(
        "doxygen",
        content = """#!/bin/sh
set -e
for cand in /usr/bin/doxygen /usr/local/bin/doxygen; do
  if [ -x "$cand" ]; then exec "$cand" "$@"; fi
done
echo "sai: doxygen not found on host; on Debian/Ubuntu try: apt-get install -y doxygen libclang1-14" >&2
exit 127
""",
        executable = True,
    )
    rctx.file(
        "BUILD.bazel",
        "exports_files([\"doxygen\"], visibility = [\"//visibility:public\"])\n",
    )

sai_doxygen_linux_arm_launcher = repository_rule(
    implementation = _sai_doxygen_linux_arm_launcher_impl,
    attrs = {},
)
