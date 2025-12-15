load("@rules_cc//cc:defs.bzl", "cc_library")

# Generate compat.h from template
genrule(
    name = "compat_h",
    srcs = ["compat/compat.h.in"],
    outs = ["compat/compat.h"],
    cmd = """
        sed -e 's/#cmakedefine HAVE_VDPRINTF/#define HAVE_VDPRINTF/' \
            -e 's/#cmakedefine HAVE_ASPRINTF/#define HAVE_ASPRINTF/' \
            -e 's/#cmakedefine HAVE_VASPRINTF/#define HAVE_VASPRINTF/' \
            -e 's/#cmakedefine HAVE_GETLINE/#define HAVE_GETLINE/' \
            -e 's/#cmakedefine HAVE_STRNDUP/#define HAVE_STRNDUP/' \
            -e 's/#cmakedefine HAVE_STRNSTR/\\/\\* #undef HAVE_STRNSTR \\*\\//' \
            -e 's/#cmakedefine HAVE_STRDUPA/#define HAVE_STRDUPA/' \
            -e 's/#cmakedefine HAVE_STRCHRNUL/#define HAVE_STRCHRNUL/' \
            -e 's/#cmakedefine HAVE_GET_CURRENT_DIR_NAME/#define HAVE_GET_CURRENT_DIR_NAME/' \
            -e 's/#cmakedefine HAVE_PTHREAD_MUTEX_TIMEDLOCK/#define HAVE_PTHREAD_MUTEX_TIMEDLOCK/' \
            -e 's/#cmakedefine HAVE_REALPATH/#define HAVE_REALPATH/' \
            -e 's/#cmakedefine HAVE_LOCALTIME_R/#define HAVE_LOCALTIME_R/' \
            -e 's/#cmakedefine HAVE_GMTIME_R/#define HAVE_GMTIME_R/' \
            -e 's/#cmakedefine HAVE_TIMEGM/#define HAVE_TIMEGM/' \
            -e 's/#cmakedefine HAVE_STRPTIME/#define HAVE_STRPTIME/' \
            -e 's/#cmakedefine HAVE_MMAP/#define HAVE_MMAP/' \
            -e 's/#cmakedefine HAVE_STRCASECMP/#define HAVE_STRCASECMP/' \
            -e 's/#cmakedefine HAVE_SETENV/#define HAVE_SETENV/' \
            -e 's/#cmakedefine IS_BIG_ENDIAN/\\/\\* #undef IS_BIG_ENDIAN \\*\\//' \
            -e 's/#cmakedefine HAVE_STDATOMIC/#define HAVE_STDATOMIC/' \
            $(SRCS) > $@
    """,
)

# Generate ly_config.h from template
genrule(
    name = "ly_config_h",
    srcs = ["src/ly_config.h.in"],
    outs = ["src/ly_config.h"],
    cmd = """
        sed -e 's/@LYD_VALUE_SIZE@/24/' \
            -e 's/@CMAKE_SHARED_MODULE_SUFFIX@/.so/' \
            -e 's|@PLUGINS_DIR_TYPES@|/usr/lib/libyang/types|' \
            -e 's|@PLUGINS_DIR_EXTENSIONS@|/usr/lib/libyang/extensions|' \
            $(SRCS) > $@
    """,
)

# Generate version.h from template
genrule(
    name = "version_h",
    srcs = ["src/version.h.in"],
    outs = ["src/version.h"],
    cmd = """
        sed -e 's/@LIBYANG_MAJOR_SOVERSION@/3/' \
            -e 's/@LIBYANG_MINOR_SOVERSION@/9/' \
            -e 's/@LIBYANG_MICRO_SOVERSION@/1/' \
            -e 's/@LIBYANG_SOVERSION_FULL@/3.9.1/' \
            -e 's/@LIBYANG_MAJOR_VERSION@/3/' \
            -e 's/@LIBYANG_MINOR_VERSION@/12/' \
            -e 's/@LIBYANG_MICRO_VERSION@/2/' \
            -e 's/@LIBYANG_VERSION@/3.12.2/' \
            $(SRCS) > $@
    """,
)

# Copy metadata.h to src/ so it can be in the same cc_library with other public headers
genrule(
    name = "metadata_h",
    srcs = ["src/plugins_exts/metadata.h"],
    outs = ["src/metadata.h"],
    cmd = "cp $< $@",
)

# Public headers from src/ exposed as libyang/
# metadata.h is copied to src/ so it's included with other headers
cc_library(
    name = "public_headers",
    hdrs = [
        "src/context.h",
        "src/dict.h",
        "src/in.h",
        "src/libyang.h",
        "src/log.h",
        "src/out.h",
        "src/parser_data.h",
        "src/parser_schema.h",
        "src/plugins.h",
        "src/plugins_exts.h",
        "src/plugins_types.h",
        "src/printer_data.h",
        "src/printer_schema.h",
        "src/set.h",
        "src/tree.h",
        "src/tree_data.h",
        "src/tree_edit.h",
        "src/tree_schema.h",
        "src/hash_table.h",
        ":ly_config_h",
        ":version_h",
        ":metadata_h",
    ],
    strip_include_prefix = "src",
    include_prefix = "libyang",
    visibility = ["//visibility:public"],
)

cc_library(
    name = "libyang3",
    srcs = glob([
        "src/*.c",
        "src/plugins_types/*.c",
        "src/plugins_exts/*.c",
        "compat/*.c",
    ], exclude = [
        "src/cmd_*.c",  # CLI commands
    ]) + [
        ":ly_config_h",
        ":version_h",
        ":compat_h",
    ],
    hdrs = glob([
        "src/*.h",
        "src/plugins_exts/*.h",
        "models/*.h",
    ]) + [":compat_h"],
    includes = [
        ".",
        "src",
        "src/plugins_exts",
        "compat",
    ],
    copts = [
        "-std=c11",
        "-Wall",
        "-Wextra",
        "-fvisibility=hidden",
        "-DLIBYANG_BUILD",
        "-DNDEBUG",
        "-O2",
        "-DPCRE2_CODE_UNIT_WIDTH=8",
        # Enable large file support for 32-bit arch (from Makefile)
        "-D_FILE_OFFSET_BITS=64",
        # Position independent code for shared library
        "-fPIC",
    ],
    linkopts = [
        "-lm",
        "-ldl",
        "-lpthread",
    ],
    deps = [
        "@libyang3_deps//libpcre2-dev:libpcre2",
        ":public_headers",
    ],
    visibility = ["//visibility:public"],
)

# Shared library for runtime use
cc_shared_library(
    name = "libyang3_shared",
    deps = [":libyang3"],
    visibility = ["//visibility:public"],
)
