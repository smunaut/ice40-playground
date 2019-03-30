iCE40 Text Mode video
=====================

Overview
--------

### Main specs

 * 240x64 screen area
 * 8x16 glyphs
 * 2 sets of 256 possible glyphs
 * X/Y flips of glyphs
 * Multiple drawing / color mapping modes


### Block diagram

```
      ,--------,            ,--------,             ,--------,
      |        |            |        |             |        |
X/Y ->| Screen |->[ char ]->| Glyph  |->[ pixel ]->| Color  |->[ output color ]
      | Memory |   +attr    | Memory |      ,----->| Memory |
      |        |     \      |        |     /       |        |
      '--------'      \     '--------'    /        '--------'
                       \_________________/

```


### Implementation notes

 * The implementation actually produces 2 pixels at once to be able to support
   1080p output on the UP5k

 * The screen memory and glyph memory are implement using 1 SPRAM each.
   The color memory uses two EBR block

 * Because two pixels are produced at once, we need to do two lookups
   in color memory, so we need two blocks with the same content to have two
   read ports
 
 * External read write access to those memory is allowed via a bus interface,
   the core manages the access sharing between the bus interface and the video
   lookups.

     * During the active portion of the video area, the Screen memory only
       requires 1 lookup every 4 cycles and Glyph memory only 1 lookup every
       2 cycles. So those memory can be accessed without much issues at any
       time.

     * The color memory however is needed by the video core at every cycle
       during the active portion of the video and any bus access will stall
       until either horizontal blanking or vertical blanking.


Sreen memory
------------

### Address mapping :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| 1 | 0 |           Y           |               X               |
'---------------------------------------------------------------'
```

Screen memory is mapped from `0x8000` to `0xbfff` with each location
representing one character on screen.


### Data mapping :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|         attributes            |          char                 |
'---------------------------------------------------------------'
```

Each data word contains the actual character to fetch from the
glyph memory along with some attributes that will configure how
to draw it on-screen


Glyph memory
------------

### Address mapping :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| 1 | 1 | s |              char             |       Y       | X |
'---------------------------------------------------------------'
```

Glyph memory is mapped from `0xC000` to `0xFFFF` with each location
representing the color index of 4 pixels.

 * `s`: Which character set the glyph belongs to
 * `char`: Character index in that char set
 * `Y`: line
 * `X`: msb of the X position. 0=left half, 1=right half


### Data mapping :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|      px0      |      px1      |      px2      |      px3      |
'---------------------------------------------------------------'
```

`px0` being the left most pixel and `px3` being the right most one.

The value of these field is what's going to be used, in combination
with the attributes from the screen memory to perform the final
color lookup in the color memory.


Color Memory
------------

### Address mapping :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| 0 | 1 | 1 |       (reserved)      |  palette  |  color index  |
'---------------------------------------------------------------'
```

The color memory contains 16 palettes of 16 colors. How the lookup
is performed depend on which drawing mode is active for the current
character. Refer to the 'drawing mode` section below.


### Data mapping :

The 16 bit word is directly provided to the input. In practice
when connected to a 3-bit HDMI PMOD, only the 3 LSBs are used.


Drawing mode
------------

### Attribute field format :

```
,-------------------------------,
| f | e | d | c | b | a | 9 | 8 |
|-------------------------------|
|                       | m | s |
'-------------------------------'
```

* `m`: Define the drawing mode for this character (see below)
* `s`: Define which character set to use


### Palette mode

```
,-------------------------------,
| f | e | d | c | b | a | 9 | 8 |
|-------------------------------|
|    palette    | X | Y | 0 | s |
'-------------------------------'
```

In this mode, the `palette` field of the attribute is combined with the `px?`
value from the glyph to perform the lookup into the color memory and obtain
the final color.

This mode also allows to perform `X` and `Y` flip of the glyph.


### Direct mode

```
,-------------------------------,
| f | e | d | c | b | a | 9 | 8 |
|-------------------------------|
|    fg     |    bg     | 1 | s |
'-------------------------------'
```

In this mode, a foreground and a background color are specified directly
in the attributes.


Assuming `px` is the value from the glyph, color lookup is done like this :

 * `00x0`: Perform lookup in palette `0` for color index `{ x, bg }`
 * `00y1`: Perform lookup in palette `0` for color index `{ y, fg }`
 * Other value: Perform lookup in palette `1` for color index `px`

This allows the first 4 colors to be customized directly per character and
remapped. For instance to change text color without need for different glyphs.
The default for a monochrome font would be to have `x = 0` and `y = 1` so
that in palette `0`, the first 8 entries are background colors and the last
8 entries are foreground ones.

If the glyph uses other colors, then those are looked up directly in palette
`1`. This way the glyph can also use static colors that don't depend on the
defined foreground and background color for that character.
