#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hexdump.h"

static char hexd_buff[4096];
static const char hex_chars[] = "0123456789abcdef";

/*! Convert binary sequence to hexadecimal ASCII string.
 *  \param[out] out_buf  Output buffer to write the resulting string to.
 *  \param[in] out_buf_size  sizeof(out_buf).
 *  \param[in] buf  Input buffer, pointer to sequence of bytes.
 *  \param[in] len  Length of input buf in number of bytes.
 *  \param[in] delim  String to separate each byte; NULL or "" for no delim.
 *  \param[in] delim_after_last  If true, end the string in delim (true: "1a:ef:d9:", false: "1a:ef:d9");
 *                               if out_buf has insufficient space, the string will always end in a delim.
 *  \returns out_buf, containing a zero-terminated string, or "" (empty string) if out_buf == NULL or out_buf_size < 1.
 *
 * This function will print a sequence of bytes as hexadecimal numbers, adding one delim between each byte (e.g. for
 * delim passed as ":", return a string like "1a:ef:d9").
 *
 * The delim_after_last argument exists to be able to exactly show the original osmo_hexdump() behavior, which always
 * ends the string with a delimiter.
 */
const char *osmo_hexdump_buf(char *out_buf, size_t out_buf_size, const unsigned char *buf, int len, const char *delim,
			     bool delim_after_last)
{
	int i;
	char *cur = out_buf;
	size_t delim_len;

	if (!out_buf || !out_buf_size)
		return "";

	delim = delim ? : "";
	delim_len = strlen(delim);

	for (i = 0; i < len; i++) {
		const char *delimp = delim;
		int len_remain = out_buf_size - (cur - out_buf) - 1;
		if (len_remain < (2 + delim_len)
		    && !(!delim_after_last && i == (len - 1) && len_remain >= 2))
			break;

		*cur++ = hex_chars[buf[i] >> 4];
		*cur++ = hex_chars[buf[i] & 0xf];

		if (i == (len - 1) && !delim_after_last)
			break;

		while (len_remain > 1 && *delimp) {
			*cur++ = *delimp++;
			len_remain--;
		}
	}
	*cur = '\0';
	return out_buf;
}

/*! Convert binary sequence to hexadecimal ASCII string
 *  \param[in] buf pointer to sequence of bytes
 *  \param[in] len length of buf in number of bytes
 *  \returns pointer to zero-terminated string
 *
 * This function will print a sequence of bytes as hexadecimal numbers,
 * adding one space character between each byte (e.g. "1a ef d9")
 *
 * The maximum size of the output buffer is 4096 bytes, i.e. the maximum
 * number of input bytes that can be printed in one call is 1365!
 */
char *osmo_hexdump(const unsigned char *buf, int len)
{
	osmo_hexdump_buf(hexd_buff, sizeof(hexd_buff), buf, len, " ", true);
	return hexd_buff;
}
