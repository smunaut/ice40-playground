HUB75 LED Panel driver IP core
==============================

This core allows to drive LED panel chains using the 'classic' HUB75
protocol. The default top level contains a frame buffer but it's also
possible to re-use the lower level components to drive a display without
the need for a full frame buffer and just generate the pixel data
'just-in-time'.

The LEDS are modulated using Binary Coded Modulation which allow to
efficiently vary their intensity efficiently.
[This video](https://www.youtube.com/watch?v=Sq8SxVDO5wE) by Mike Harisson
explains the concept of BCM very well.

The geometry of the panel and various aspecs are fully configurable through
parameters given to the cores.

See the doc/ directory for more information about the internals of this
core.

This core is licensed under the GNU Lesser General Public v3
(see LICENSE.lgpl3)
