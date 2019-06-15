RGB Panel driver for iCEBreaker board
=====================================

This is an example usage of the Hub75 driver IP in this repository
and implements driving RGB panels using the iCEBreaker board along
with the RGB Panel PMOD.

Default configuration is for a 64x64 panel using 1:32 multiplex.
Note that some panels have the Red and Blue channels swapped, so
you might have to adapt this ...

This example has 3 modes of operations explained below. Each
mode is selected by uncommenting the appropriate `define` at the
top of the `top.v` file.

Pixel format
------------

The color mapping from the `BITDEPTH` wide word sent to the core and the
data sent to the panels in the various channels is fully configurable by
modifying the `hub75_colormap` module.

The default however is to have the following pixel format for each bit depth:
 * `BITDEPTH == 8` : `RGB332`
 * `BITDEPTH == 16` : `RGB565`
 * `BITDEPTH == 24` : `RGB888`
(meaning with Red channel in the MSB of the word and sent as litte-endian).

Then the channel mapping is to have :
 * Channel 0 (`hub75_data[3*n+0]`) = Blue
 * Channel 1 (`hub75_data[3*n+1]`) = Green
 * Channel 2 (`hub75_data[3*n+2]`) = Red

Check the file `data/top-icebreaker.pcf` to check that this data channel
mapping matches your panels since several pinout have been seen in the
wild.


Panel frequency
---------------

The build default is to run the panel at 30 MHz. This can be too fast for some
panel. During build you can use `make PANEL=slow` to select PLL settings that
will run the panel at 24 MHz instead.


Pattern mode
------------

This generates a Red & Blue gradient across the two axises and then some
moving green lines across. Very simple example of generating data directly
on the FPGA itself and can also be used as a pretty reliable test that all
works well.


Video play mode
---------------

In this mode, frames are read from the SPI flash and displayed in sequence.

For this to work, you need some video content to be preloaded into the flash.
You can use the special `make data-prog` target to load a default nyan cat
animation.

To load your own animation in flash, checkout the `ADDR_BASE` and `N_FRAMES`
parameters that tell the module where to look in flash for the image data.

Data needs to be raw frame in RGB565 format, independent of the `BITDEPTH`
parameter. It will internally convert those to the appropriate bitdepth.


Video streaming mode
--------------------

In this mode, video content is streamed from the host PC to the FPGA using
SPI (through the FT2232H used for programming the FPGA).

A control software `stream.py` is provided in the `sw/` sub-directory.
It required Python 3.x and [pyftdi](https://github.com/eblot/pyftdi).

And example usage would be :

```
./stream.py --fps 10 --loop --input ../data/nyan_glitch_64x64x16.raw
```

See the `--help` for other options available.

To prepare content, you can use ffmpeg :

```
ffmpeg -i input.mp4 -filter_complex "[0:v]crop=540:540,scale=64:64" -pix_fmt rgb565 -f rawvideo output.raw
```

Obviously the number for the `crop` filter need to be adjusted for your source
material to get a square image that selects the best region to show. Also, you
can do use unix FIFOs to directly pipe content from `ffmpeg` to the `stream.py`
application without the need for intermediate files.


Single PMOD support
-------------------

By default the code is built to have a [double-width PMOD](https://github.com/icebreaker-fpga/icebreaker-pmod/tree/master/led-panel)
connected on the PMOD1A and PMOD1B port.

There is an alternate [single-width PMOD](https://github.com/icebreaker-fpga/icebreaker-pmod/tree/master/led-panel-single)
that uses a bit of external logic to reduce the number of IO lines used (so you
have more free PMODs slots). To build the project with this option, use
`make BOARD=icebreaker-single`.

The `pcf` is by default configured to have this PMOD on slot P1A, but you can
edit `icebreaker-single.pcf` to change the pin assignements if it's plugged
somewhere else.

If you happen to have two of those PMODs, you can plug them on slot P1A and
P1B and use `make BOARD=icebreaker-single2x`.
