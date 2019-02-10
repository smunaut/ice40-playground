CORE := misc

RTL_SRCS_misc = $(addprefix rtl/, \
	delay.v \
	glitch_filter.v \
	ram_sdp.v \
	pwm.v \
)

include $(ROOT)/build/core-magic.mk
