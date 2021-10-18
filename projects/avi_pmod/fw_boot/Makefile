CROSS ?= riscv-none-embed-

CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

CFLAGS=-Wall -Os -march=rv32i -mabi=ilp32 -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs

boot.elf: lnk-boot.lds boot.S
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,lnk-boot.lds,--strip-debug -o $@ boot.S

%.hex: %.bin
	hexdump -ve '1/4 "%08x\n"' $< > $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f *.bin *.hex *.elf *.o

.PHONY: clean
