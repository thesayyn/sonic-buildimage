# SONiC telemetry package (Bazel build)

SONIC_TELEMETRY_VERSION = 0.1

SONIC_TELEMETRY = sonic-telemetry_$(SONIC_TELEMETRY_VERSION)_$(CONFIGURED_ARCH).deb
$(SONIC_TELEMETRY)_SRC_PATH = $(SRC_PATH)/sonic-gnmi
$(SONIC_TELEMETRY)_DEPENDS += $(LIBSWSSCOMMON_DEV)
$(SONIC_TELEMETRY)_RDEPENDS += $(LIBSWSSCOMMON)
SONIC_MAKE_DEBS += $(SONIC_TELEMETRY)

export SONIC_TELEMETRY SONIC_TELEMETRY_VERSION

# The .c, .cpp, .h & .hpp files under src/{$DBG_SRC_ARCHIVE list}
# are archived into debug one image to facilitate debugging.
DBG_SRC_ARCHIVE += sonic-gnmi
