CORE := video

DEPS_video := no2misc

RTL_SRCS_video := $(addprefix rtl/, \
	hdmi_phy_2x.v \
	hdmi_phy_4x.v \
	hdmi_text_2x.v \
	vid_shared_ram.v \
	vid_text.v \
	vid_tgen.v \
)

include $(NO2BUILD_DIR)/core-magic.mk
