MEMORY
{
    ROM (rx)    : ORIGIN = 0x00000000, LENGTH = 0x0400
}
ENTRY(_start)
SECTIONS {
    .text :
    {
        . = ALIGN(4);
        *(.text.start)
        *(.text)
        *(.text*)
    } >ROM
}
