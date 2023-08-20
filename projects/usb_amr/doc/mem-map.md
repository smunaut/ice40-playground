AC97 controller registers
=========================

```
`0x00`	CSR
		[3]     (R)  Ring Frequency Indicator
		[2]	(RW) GPIO ena
		[1]	(RW) AC97_reset_n
		[0]	(RW) Run

`0x01`	Low Level Status
		[31]	(R)  Codec Ready
		[28:16] (R)  Slot Request (bit 28=Slot 12, bit 16=Slot 0)
		[12:0]	(R)  Slot Valid   (bit 12=Slot 12, bit  0=Slot 0)
		(Write clears)

`0x02`	Codec Register Access
		[31]	(R)  Busy
		[30]	(RW) Write Enable
		[29]    (R)  Read Error flag
		[21:16] (RW) Register Address
		[15:0]  (RW) Register Value

`0x04`	Codec GPIO Input
		[19:0]	(R)  GPIO Input

`0x05`	Codec GPIO Output
		[19:0]	(RW) GPIO Output

`0x06`	FIFO Data
		[31]	(R)  Empty flag (for read)
		[15:0] 	(RW) PCM 16 bits signed

`0x07`	FIFO Control/Status
		[31]	(RW) FIFO PCM In - Enable
		[30]	(RW) FIFO PCM In - Flush
		[29]    (R)  FIFO PCM In - Full
		[28]    (R)  FIFO PCM In - Empty
		[27:16]	(R)  FIFO PCM In - Level

		[15]    (RW) FIFO PCM Out - Enable
		[14]    (RW) FIFO PCM Out - Flush
		[13]    (R)  FIFO PCM Out - Full
		[12]    (R)  FIFO PCM Out - Empty
		[11:0]  (R)  FIFO PCM Out - Level
```
