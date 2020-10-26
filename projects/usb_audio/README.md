USB Audio Class demo
====================

For the icebreaker, the USB hardware connections are :
  * `P1B4`: USB DP
  * `P1B3`: USB DN
  * `P1B2`: Pull up. Resistor of 1.5 kOhm to USB DP 

and the Audio PMOD on P1A.

For the bitsy, refer to the PCF (or edit it) to know what pins
are used for audio out.

To run :
  * Build and flash the bitstream
      * This will build `fw/boot.hex` and include it as the BRAM initial data
      * `make prog` or `make dfuprog`

  * Flash the main application code in SPI at offset 1M
      * `make -C fw prog` or `make -C fw dfuprog`
