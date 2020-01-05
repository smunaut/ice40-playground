#pragma once
#include <stdbool.h>

const char *osmo_hexdump_buf(char *out_buf, size_t out_buf_size, const unsigned char *buf, int len, const char *delim,
			     bool delim_after_last);

char *osmo_hexdump(const unsigned char *buf, int len);
