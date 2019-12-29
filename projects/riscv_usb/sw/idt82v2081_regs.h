#ifndef _IDT82_REGS_H
#define _IDT82_REGS_H

/* Section 4.1 of Data Sheet */
enum idt82v2081_reg {
	IDT_REG_ID,	/* control */
	IDT_REG_RST,
	IDT_REG_GCF,
	IDT_REG_TERM,
	IDT_REG_JACF,
	IDT_REG_TCF0,	/* Tx path control */
	IDT_REG_TCF1,
	IDT_REG_TCF2,
	IDT_REG_TCF3,
	IDT_REG_TCF4,
	IDT_REG_RCF0,	/* Rx path control */
	IDT_REG_RCF1,
	IDT_REG_RCF2,
	IDT_REG_MAINT0,	/* Net Diag Ctrl */
	IDT_REG_MAINT1,
	IDT_REG_MAINT2,
	IDT_REG_MAINT3,
	IDT_REG_MAINT4,
	IDT_REG_MAINT5,
	IDT_REG_MAINT6,
	IDT_REG_INTM0,	/* Interrupt Control */
	IDT_REG_INTM1,
	IDT_REG_INTES,
	IDT_REG_STAT0,	/* Line Status */
	IDT_REG_STAT1,
	IDT_REG_INTS0,	/* Interrupt Status */
	IDT_REG_INTS1,
	IDT_REG_CNT0,	/* Counter */
	IDT_REG_CNT1,
};

#define IDT_GCF_T1E1_E1 	(0 << 2)
#define IDT_GCF_T1E1_T1 	(1 << 2)
#define IDT_GCF_T1E1_MASK 	(1 << 2)

#define IDT_TERM_T_SHIFT	3
#define IDT_TERM_T_MASK		(7 << IDT_TERM_T_SHIFT)
#define IDT_TERM_R_SHIFT	0
#define IDT_TERM_R_MASK		(7 << IDT_TERM_R_SHIFT)

#define IDT_TCF1_PULS_MASK	0xF

#define IDT_TCF2_SCAL_MASK	0x3F

#define IDT_RCF2_MG_MASK	3
#define IDT_RCF2_UPDW_SHIFT	2
#define IDT_RCF2_UPDW_MASK	(3 << IDT_TERM_INT_75)
#define IDT_RCF2_SLICE_SHIFT	4
#define IDT_RCF2_SLICE_MASK	(3 << IDT_RCF2_SLICE_SHIFT)

#define IDT_INTM0_EQ		(1 << 7)	/* equalizer out of range */
#define IDT_INTM0_IBLBA		(1 << 6)	/* in-band LB act detect */
#define IDT_INTM0_IBLBD		(1 << 5)	/* in-band LB deact detect */
#define IDT_INTM0_PRBS		(1 << 4)	/* prbs sync signal detect */
#define IDT_INTM0_TCLK		(1 << 3)	/* tclk loss */
#define IDT_INTM0_DF		(1 << 2)	/* driver failure */
#define IDT_INTM0_AIS		(1 << 1)	/* Alarm Indication Signal */
#define IDT_INTM0_LOS		(1 << 0)	/* Loss Of Signal */

#define IDT_INTM1_DAC_OV	(1 << 7)	/* DAC arithmetic overflow */
#define	IDT_INTM1_JA_OV		(1 << 6)	/* JA overflow */
#define IDT_INTM1_JA_UD		(1 << 5)	/* JA underflow */
#define IDT_INTM1_ERR		(1 << 4)	/* PRBS/QRBS logic error detect */
#define IDT_INTM1_EXZ		(1 << 3)	/* Receive excess zeros */
#define IDT_INTM1_CV		(1 << 2)	/* Receive error */
#define IDT_INTM1_TIMER		(1 << 1)	/* One second timer expiration */
#define IDT_INTM1_CNT		(1 << 0)	/* Counter overflow */

/* STAT0 == INTES == INTS0 == INTM0 */

/* INTS1 == INTM1 */

#define IDT_STAT1_RLP		(1 << 5)
#define IDT_STAT1_ATT_MASK	0x1F

#endif /* _IDT82_REGS_H */
