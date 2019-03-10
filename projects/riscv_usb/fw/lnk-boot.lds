MEMORY
{
    ROM (rx)    : ORIGIN = 0x00000000, LENGTH = 0x0400
}
SECTIONS {
    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
    } >ROM
}
