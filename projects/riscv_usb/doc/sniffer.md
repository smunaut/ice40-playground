Wiring
------


	       ,-----------------------------------------,  Top  Bot
               |                                         |  B3   B2
               |   /-\                                   |  B1   B0
        ,------|   \-/                                   |  GND  GND
-------'       |                                         |  A5   A4
-------,       |                                         |  A3   A2
        `------|                                         |  A1   A0
               |                                         |  GND  GND
               |                                         |  Vs   Vio
	       ,-----------------------------------------,


Vio - LIU power (3v3)
GND - LIU ground

A0  - LIU MOSI
A1  - LIU MISO
A2  - LIU CLK
A3  - Debug uart TX (1 Mbaud)
A4  - LIU CSn[0]
A5  - LIU CSn[1]

B0  - LIU RCLK0
B1  - LIU RD0
B2  - LIU RCLK1
B3  - LIU RD1


Status:
-------

* Color:
   - Red : Means either the host application isn't running and the interface
           is not active.

           This is also used in case the interface is active but both channels
	   are not synchronized. But in this case, it will also be flashing.

   - Blue / Green: One of the two link has not acquired multi-frame alignement

   - Cyan : Both links have multiframe alignement.

* Blinking: If the led is blinking it means there was either a desync
            or CRC error in the last second.
