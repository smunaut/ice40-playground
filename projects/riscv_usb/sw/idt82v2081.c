#include <stdint.h>

#include "idt82v2081.h"
#include "idt82v2081_regs.h"

/*! \brief Set or clear some (masked) bits inside a register
 *  \param[in] e4k reference to the tuner
 *  \param[in] reg number of the register
 *  \param[in] mask bit-mask of the value
 *  \param[in] val data value to be written to register
 *  \returns 0 on success, negative in case of error
 */
static int idt82_reg_set_bit_mask(struct idt82 *idt, uint8_t reg,
				  uint8_t mask, uint8_t val)
{
	uint8_t tmp = idt82_reg_read(idt, reg);

	if ((tmp & mask) == val)
		return 0;

	return idt82_reg_write(idt, reg, (tmp & ~mask) | (val & mask));
}

int idt82_termination(struct idt82 *idt, enum idt82_term term)
{
	uint8_t puls, scal;

	idt82_reg_set_bit_mask(idt, IDT_REG_TERM, term | (term << IDT_TERM_T_SHIFT),
			       IDT_TERM_T_MASK | IDT_TERM_R_MASK);

	switch (idt->mode) {
	case IDT_MODE_E1:
		if (term == IDT_TERM_INT_75)
			puls = 0;
		else
			puls = 1;
		scal = 0x21;
		break;
	case IDT_MODE_T1:
		/* FIXME: different length! */
		puls = 2;
		scal = 0x36;
		break;
	case IDT_MODE_J1:
		puls = 7;
		scal = 0x36;
		break;
	default:
		return -1;
	}

	idt82_reg_set_bit_mask(idt, IDT_REG_TCF1, puls, IDT_TCF1_PULS_MASK);
	idt82_reg_set_bit_mask(idt, IDT_REG_TCF2, scal, IDT_TCF2_SCAL_MASK);

	idt->term = term;

	return 0;
}

int idt82_mode(struct idt82 *idt, enum idt82_mode mode)
{
	switch (mode) {
	case IDT_MODE_E1:
		idt82_reg_set_bit_mask(idt, IDT_REG_GCF, IDT_GCF_T1E1_E1,
				       IDT_GCF_T1E1_MASK);
		break;
	case IDT_MODE_T1:
	case IDT_MODE_J1:
		idt82_reg_set_bit_mask(idt, IDT_REG_GCF, IDT_GCF_T1E1_T1,
				       IDT_GCF_T1E1_MASK);
		break;
	}
	idt->mode = mode;

	return 0;
}

int idt82_get_errcount(struct idt82 *idt)
{
	uint16_t ret;
	int rc;

	rc = idt82_reg_read(idt, IDT_REG_CNT0);
	if (rc < 0)
		return rc;

	ret = rc;

	rc = idt82_reg_read(idt, IDT_REG_CNT1);
	if (rc < 0)
		return rc;

	ret |= (rc << 8);

	return ret;
}

/* return in dB, range is return value ... (value + 2) */
int idt82_get_line_att(struct idt82 *idt)
{
	int rc;

	rc = idt82_reg_read(idt, IDT_REG_STAT1);
	if (rc < 0)
		return rc;

	return (rc & IDT_STAT1_ATT_MASK)*2;
}

int idt82_init(struct idt82 *idt, bool monitor)
{
	idt82_reg_write(idt, IDT_REG_RST,  0x00);	/* Reset to defaults */

	idt82_mode(idt, IDT_MODE_E1);
	idt82_termination(idt, IDT_TERM_INT_120);

	idt82_reg_write(idt, IDT_REG_TCF0, 0x10);	/* Disable TX */

	if (monitor)
		idt82_reg_write(idt, IDT_REG_RCF2, 0x19);	/* 22 dB monitor mode */

	return 0;
}

