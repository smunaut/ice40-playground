iCE40 USB Core Architecture
===========================

Overview
--------

![Architecture diagram](ice40-usb.svg "Architecture diagram")

### Design goals

The goal was to write a core that would be similar to the SIE you find in
classic microcontrollers that support USBs. That means it requires a soft
core to implement the actual USB stack, the hardware itself only handle up
to the _transaction_ layer of USB.

It's designed to be small but still allow full flexibility of what kind
of device it implements, supports all types of transfers, all packet
sizes and any combination of end points without having to change the
hardware configuration at all.

### Operation principle

Each endpoint can be configured as any type and be either single or
double buffered. When the core receives a token from the host, it will
look up the EP status and check if there is any buffer ready to send/receive.

The data buffers are fully shared between each end point, the address field
of each buffer descriptor has to be filled by the software stack to ensure
no conflicts.

To know if/when transfer happens, the core can either generate/queue event
in a FIFO or the software can also just poll the EP status fields.


### Special handling for Control Endpoints

End Point 0 and Control endpoint in general are almost treated like any
other endpoint, and you can use control transfer on any endpoint if you
wish.

However the hardware does offer a couple of special features to make the
software implementation of control transfer easier.

The first one is called the "Control Endpoint Lockout" or _CEL_ for short.
If enabled, any `SETUP` packet received by a control endpoint will trigger
the lockout. This will in turn cause any `IN` or `OUT` transactions on a
control endpoint to be `NAKed` to make sure that the soft core / usb stack
has time to properly analyze the received `SETUP` packet before sending
any response in case previous buffers for `IN`/`OUT` were left overs from
aborted transactions. This makes handling error cases much easier.

The second feature is a special double buffer mode for control endpoints
where instead of having two buffers alternating, you have two buffers
descriptors, the first one is used for `OUT` transactions and the second
one is used for `SETUP` transactions. Again, this makes the software stack
implementation a bit easier.


### Interfaces

 * Wishbone interface for the CSRs and Buffer Descriptors
    * Clocked at 48 MHz
    * Details of the [Memory Map](mem-map.md)
 * Dedicated "BRAM-style" interface to access packets payload
    * TX data buffer are write-only
    * RX data buffer are read-only
    * Can be clocked from a different clock


### Resources

 * About 390 FFs and 530 LUT4s
 * 10 `SB_RAM40_4K`
    * 8 are used for 2k RX and 2k TX data buffers and could be resized
      as needed


### Remarks

Although the core has been developped with the iCE40 in mind, it should be
easily portable to other FPGAs as there is very few harware specific blocks
inside. (Mostly just the IOs and BRAMs)


Modules
-------

### PHY `usb_phy.v`

This module mostly just contains the IO tristate buffers and also a small
glitch filter to improve signal quality.

### TX Low Level `usb_tx_ll.v`

This module implements the transmit side of bit stuffing, differential coding,
symbol mapping and transmit baudrate timing.

### TX Packet `usb_tx_pkt.v`

This module handles the sending of packet. Handles adding header, CRC and
serializing into a bitstream.

### RX Low Level `usb_rx_ll.v`

This module takes care of receive clock recovery, symbol unmapping,
differential decoding and bit-unstuffing. It provides a stream of valid
bits to the upstream block along with markers for packet sync and
end-of-packet.

### RX Packet `usb_rx_pkt.v`

This takes the recovered bitstream from the low-level module and reconstructs
packet, doing checks along the way (PID check / CRC check).

### Transaction `usb_trans.v`

This module is the heart of the USB core. It implements the transaction layer
of USB. This means all the diagrams of Chapter 8 of the USB specifications.

Because all the decisions to make are rather complex, this block main logic
is implemented using microcode. So you have a very special purpose CPU (see
[Microcode instructions](microcode.md) for its very limited instruction set),
surrounded by some helper peripherals to control the TX/RX packets blocks,
direct data appropriately and interact with the memory containing all the
endpoint buffer descriptors and status information.

### EP Status `usb_ep_status.v`

This memory is a BRAM that's used to store all the information about each
endpoint (status / buffer descriptors / ... ). Because it needs to be accessed
by both the microcode engine and by the softcore, it contains arbitration
logic since the iCE40 doesn't suport true-dual-port RAM.

### EP Data Buffers `usb_ep_buf.v`

This is just a dual-port RAM with different read/write clocks and port width.

Because the synthesis tool isn't yet capable of inferring this optimally, it was
written by instanciating the iCE40 RAM primitives manually.

### Top Level `usb.v`

This is the module that ties it all together and also implement the few global
CSRs along with the wishbone interface.
