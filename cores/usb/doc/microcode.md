USB Transaction microcode
=========================

The upper 4 bits of the word determine the operation type.

Data / Ops (`0xxx` )
--------------------

### `0x0`: `NOP` - No OPeration

### `0x1`: `LD` - LoaD

```
    [2:0] - Source
            000 - evt          - Pending Events
                                 bit 0 = RX OK
                                 bit 1 = RX Error
                                 bit 2 = TX Done
                                 bit 3 = Timeout

            010 - pkt_pid      - Packet PID
            011 - pkt_pid_chk  - Packet PID (DATA0/DATA1 check)
            100 - ep_type      - End Point type
            110 - bd_state     - State of Buffer Descriptor
```

### `0x2`: `EP` - End Point operation

```
      [8] - Set Control Endpoint Lockout bit
      [7] - Issue Write Back
    [5:3] - New Buffer Descriptor State value
      [2] - Set Buffer Descriptor State
      [1] - Flip Buffer index bit (active only if EP is dual buffered)
      [0] - Flip Data Toggle bit
```

### `0x3`: `ZL` - Zero Length

### `0x4`: `TX` - Transmit packet

```
      [4] - Auto-Set DataToggle (DATA0/DATA1)
    [3:0] - Packet PID
```

### `0x5`: `NOTIFY` - Notify Host

```
    [3:0] - Notify code
```

### `0x6`: `EVT_CLR` - EVenT CLeaR

```
    [3:0] - Bit Mask of events to clear
```

### `0x7`: `EVT_RTO` - EVenT Receive Time Out

```
    [7:0] - Timeout value
```


Control flow ( `1xxx` )
-----------------------

### `JMP` / `JEQ` / `JNE`

```
      [15] - Set to 1 to denote control flow operation
      [14] - Invert the condition
    [13:8] - Target address (divided by 4)
     [7:0] - Condition Mask
     [3:0] - Condition Value
```

This performs conditional jumps to any address where the two LSBs are clear (i.e. aligned to 4).
