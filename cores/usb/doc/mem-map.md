iCE40 USB Core Memory Map
=========================

Global CSRs
-----------

### Control / Status (Read / Write addr `0x00`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| p |evt| cs| ce|bsa|bra|brp|sfp| m |          addr             |
'---------------------------------------------------------------'
```

  * `p`   : Enables DP pull-up
  * `evt` : Event pending
  * `cs`  : Control Endpoint Lockout - State [Read Only]
  * `ce`  : Control Endpoint Lockout - Enable
  * `bsa` : Bus Suspend Asserted
  * `bra` : Bus Reset Asserted
  * `brp` : Bus Reset Pending
  * `sfp` : Start-of-Frame Pending
  * `m`   : Enable address matching
  * `addr`: Configure address matching


### Action ( Write addr `0x01` )

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|  rsvd | cr|     /     |brc|sfc|               /               |
'---------------------------------------------------------------'
```

  * `cr` : Control Endpoint Lockout - Release
  * `brc`: Bus Reset Clear
  * `sfc`: Start-of-Frame Clear


### Events (Read addr `0x02`)

This contains info about the generated events from the transaction
microcode.

It can either contain info about the last event only along with a
count of events since last read, or it can be a FIFO depending on
the core configuration.

Count mode (`EVENT_DEPTH = 0/1`) :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|      cnt      |                 event                         |
'---------------------------------------------------------------'
```

  * `cnt`: Counter of events since last read
  * `event`: Last recorded event data (see below)


FIFO mode (`EVENT_DEPTH > 1`) :

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| v | o |  rsvd |                 event                         |
'---------------------------------------------------------------'
```

  * `v`: Valid (i.e. FIFO is not empty and `event` is valid)
  * `o`: FIFO Overflow
  * `event`: event data (see below)


Event format:

```
,-----------------------------------------------,
| b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|-----------------------------------------------|
|     ucnc      |      endp     | d | s | b | / |
'-----------------------------------------------'
```

  * `ucnc`: Notification code
  * `endp`: Endpoint #
  * `d`: Direction (1=IN, 0=OUT/SETUP)
  * `s`: Is SETUP ?
  * `b`: Buffer Descriptor index


EP Status
---------

### Address:

```
,-----------------------------------------------,
| b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|-----------------------------------------------|
| 1   0   0   0 |     ep_num    |dir| 0   0   0 |
'-----------------------------------------------'
```


### Data:

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|                               | t | b |  bdm  |   |  EP type  |
'---------------------------------------------------------------'
```

  * `t`: Data Toggle (if relevant for EP type)
  * `b`: Buffer Descriptor index
  * 'bdm': Buffer descriptor mode
    - `00` - Single Buffer (index 0 only)
    - `01` - Double Buffer
    - `10` - Special Control EP mode (index 0=data, 1=setup)
  * EP Type: (`h` indicates if this EP is halted)
    - `000`: Non-existant
    - `001`: Isochronous
    - `01h`: Interrupt
    - `10h`: Bulk
    - `11h`: Control


Buffer Descriptor
-----------------

### Address:

```
,-----------------------------------------------,
| b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|-----------------------------------------------|
| 1   0   0   0 |     ep_num    |dir| 1 | i | w |
'-----------------------------------------------'
```

  * `i`: BD Index (0/1)
  * `w`: Word select


### Word 0:

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|   state   | s |  rsvd |           Buffer Length               |
'---------------------------------------------------------------'
```

  * `s`: Transactions was setup
  * BD State:
    - `000`: Empty / Unused
    - `010`: Valid, ready for Tx/RX data
    - `011`: Valid, issue STALL (and drop data)
    - `100`: Used - Success
    - `1xx`: Used - Error with xx=01/10/11 error code


### Word 1:

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|       (rsvd)      |             Buffer Pointer                |
'---------------------------------------------------------------'
```
