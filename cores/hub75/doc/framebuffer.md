Frame Buffer
============

The frame buffer allows to double buffer frames to be displayed on the screen.
It allows for tear-free image update and also to decouple the input video rate
from the actual LED panel refresh rate. It also decouples the order in which
the pixels have to be written from the order that the panel driver needs them
to control the LEDs.

General flow is as follows :


```
                   ,---------,       ,--------,       ,---------,
Host / Pixel       |  Write  |       | Frame  |       |  Read   |       Panel
Generation   ----> | Process | ----> | Buffer | ----> | Process | ----> Driver
                   '---------'       '--------'       '---------'
```



Write Process
-------------

The write process top level is the `hub75_fb_writein` module.

```            
            .---------------,
From        |    Double     |      To
Pixel  ---> |    Row        | ---> Frame
Source      |    Buffer     |      Buffer
            '---------------'
                    |
            ,---------------,
       <--> | Control logic | <-->
            '---------------'
```

This module contains a double row buffer.

So the general usage is that the user side interface is free to write an
entire row of pixels inside one of the row buffer (in any order and at
any rate).

When done, it can send a store command that will swap the double buffers,
give it a new row buffer to write the next row, while in the background the
first buffer is being written to the shared frame buffer.


Frame Buffer
------------

The frame buffer storage element itself is based on the iCE40 SPRAMs blocks.
Those have some limitations and thus the frame buffer logic has to contain
logic to make the requires adaptations:

 * They are single-port and so there needs to be arbitration logic between
   the read and write side to avoid conflicts.

 * Each RAM is a fixed 16 bits and so width adaptation depending on the
   bits / pixels might be needed.

 * Depending on the required size for the frame buffer, the logic will
   automatically decide how many SPRAMs to use and how to combine them
   (in width or depth). The resulting geometry is displayed in the debug
   output during synthesis / simulation.

All of this is handled internally in the `hub75_framebuffer` module.



Read Process
------------

The read process top level is the `hub75_fb_readout`.

```
            ,--------------------------------------,
            | Color Mapping                        |      .--------,
From        |     ,-----------,     ,--------,     |      | Double |      To
Frame  ---> | --> |   Bit     | --> | Gamma  |     | ---> | Row    | ---> Panel
Buffer      |     | Expansion |     | Lookup | --> |      | Buffer |
            |     '-----------'     '--------'     |      '--------'
            '----------|----------------|----------'          |
                       |                |                     |
            ,------------------------------------------------------,
       <--> |                   Control logic                      | <-->
            '------------------------------------------------------'
```

This module also contains a double row buffer like the write process and the
flow is very similar but in reverse.

The 'user side' (which in this case is the core of the LED driver to pilot the
LEDs) can request a row to be loaded from the shared frame buffer memory in
the background. And when it's loaded, it can 'swap' the front/back buffer to
actually read the data and it can also issue the command to load the next row.

Another specificity is that this buffer loads the same row for all banks at
a time since they will need to be send to the panels in parallel and so it
actually buffers `N_BANKS` rows and not just one.

Finally this is also during the read out that the final color mapping is done.
This color mapping step is what converts from the `BITDEPTH` bits that have
been provided to the user to the actual value that will be used for the BCM
modulation of the RGB leds.

This step can be modified to the user to suit their need (for instance, doing
a palette lookup), but by default it does a bit expansion to 24 bits RGB
(assuming a RGB332 or RGB565 or RGB888 depending on `BITDEPTH`) and then
performs a gamma correction using a built-in LUT.
