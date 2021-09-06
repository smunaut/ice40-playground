CORE := no2muacm

RTL_SRCS_no2muacm = $(addprefix bin/, \
	muacm.v \
	muacm_xclk.v \
)

include $(NO2BUILD_DIR)/core-magic.mk
