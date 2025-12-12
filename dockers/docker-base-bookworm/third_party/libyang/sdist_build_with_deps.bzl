"""
Custom sdist_build rule that supports a CcInfo dependency for native builds.
"""

load("@aspect_rules_py//py/private/py_venv:types.bzl", "VirtualenvInfo")
load("@aspect_rules_py//py/private/toolchain:types.bzl", "PY_TOOLCHAIN")

TAR_TOOLCHAIN = "@tar.bzl//tar/toolchain:type"

def _sdist_build_with_deps(ctx):
    py_toolchain = ctx.toolchains[PY_TOOLCHAIN].py3_runtime
    tar = ctx.toolchains[TAR_TOOLCHAIN]

    unpacked_sdist = ctx.actions.declare_directory("src")
    archive = ctx.attr.src[DefaultInfo].files.to_list()[0]

    # Extract the archive
    ctx.actions.run(
        executable = tar.tarinfo.binary,
        arguments = [
            "--strip-components=1",
            "-xf",
            archive.path,
            "-C",
            unpacked_sdist.path,
        ],
        inputs = [archive] + tar.default.files.to_list(),
        outputs = [unpacked_sdist],
    )

    wheel_dir = ctx.actions.declare_directory("build")
    venv = ctx.attr.venv

    # Collect include path from the single CcInfo dep
    include_path = ""
    cc_files = []

    dep = ctx.attr.dep
    if CcInfo in dep:
        cc_info = dep[CcInfo]

        # Get headers as input files and extract include path from header location
        for hdr in cc_info.compilation_context.headers.to_list():
            cc_files.append(hdr)
            # Extract the include path - find the /usr/include part
            if "/usr/include/" in hdr.path and not include_path:
                idx = hdr.path.find("/usr/include/")
                include_path = hdr.path[:idx + len("/usr/include")]

    # Also collect DefaultInfo files
    cc_files.extend(dep[DefaultInfo].files.to_list())

    # Use run_shell to properly expand $PWD to absolute path
    command = """
export LIBYANG_HEADERS="$PWD/{headers}"
exec "{python}" "{helper}" "{srcdir}" "{outdir}"
""".format(
        headers = include_path,
        python = venv[VirtualenvInfo].home.path + "/bin/python3",
        helper = ctx.file._helper.path,
        srcdir = unpacked_sdist.path,
        outdir = wheel_dir.path,
    )

    ctx.actions.run_shell(
        command = command,
        inputs = [
            unpacked_sdist,
            venv[VirtualenvInfo].home,
            ctx.file._helper,
        ] + py_toolchain.files.to_list() + ctx.attr.venv[DefaultInfo].files.to_list() + cc_files,
        outputs = [wheel_dir],
    )

    return [
        DefaultInfo(files = depset([wheel_dir])),
    ]

sdist_build_with_deps = rule(
    implementation = _sdist_build_with_deps,
    doc = """Sdist to whl build rule with CcInfo dependency support.

Extends sdist_build to allow passing a cc_library target that provides
headers needed during the native extension build.
""",
    attrs = {
        "src": attr.label(doc = "The sdist archive to build"),
        "venv": attr.label(doc = "The Python venv with build dependencies"),
        "dep": attr.label(doc = "CcInfo dependency providing headers"),
        "_helper": attr.label(
            allow_single_file = True,
            default = Label("@aspect_rules_py//uv/private/sdist_build:build_helper.py"),
        ),
    },
    toolchains = [
        PY_TOOLCHAIN,
        TAR_TOOLCHAIN,
    ],
)
