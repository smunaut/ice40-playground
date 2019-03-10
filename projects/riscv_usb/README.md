RISC-V + USB core demo
======================

For the icebreaker, the hardware connections are :
  * `P1B4`: USB DP
  * `P1B3`: USB DN
  * `P1B2`: Pull up. Resistor of 1.5 kOhm to USB DP 

To run :
  * Build and flash the bitstream
      * This will build `fw/boot.hex` and include it as the BRAM initial data

  * Flash the main application code in SPI at offset 1M
      * `make -C fw prog_fw`

  * Connect to the iCEBreaker uart console (`ttyUSB1`) with a 1M baudrate
      * and then at the `Command>` prompt, press `r` for 'run'. This will
        start the USB detection and device should enumerate
