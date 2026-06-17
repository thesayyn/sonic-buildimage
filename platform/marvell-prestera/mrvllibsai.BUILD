# Applied to the extracted mrvllibsai .deb tree (see prestera.MODULE.bazel).
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    srcs = glob(["**/*"]),
)

cc_import(
    name = "sai",
    hdrs = glob(["usr/include/**/*.h"]),
    includes = [
        "usr/include",
        "usr/include/sai",
    ],
    shared_library = "usr/lib/libsai.so",
)
