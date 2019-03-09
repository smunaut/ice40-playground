iCE40 USB Core Memory Map
=========================

Global CSR
----------

### Control (Write addr `0x000`)

```
,--------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--------------------------------------------------------------|
| p | / |       addr           |      (rsvd)               | a |
'--------------------------------------------------------------'
```

  * `p`: Enables DP pull-up
  * `a`: Ack interrupt


### Status (Read addr `0x000`)

```
,--------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--------------------------------------------------------------|
|      cnt      |     ucnc     |      endp     | d | s | b | i |
'--------------------------------------------------------------'
```

This contains info about the last generated notification from
the transaction microcode

  * `cnt`: Counter (incremented by 1 at each notify to detect misses)
  * `ucnc`: Notification code
  * `endp`: Endpoint #
  * `d`: Direction (1=IN, 0=OUT/SETUP)
  * `s`: Is SETUP ?
  * `b`: Buffer Descriptor index
  * `i`: Interrupt flag


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
,--------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--------------------------------------------------------------|
|                              | t | b |  bdm  |   |  EP type  |
'--------------------------------------------------------------'
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
    - `01s`: Interrupt
    - `10s`: Bulk
    - `11s`: Control


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
,--------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--------------------------------------------------------------|
|   state   | s |  rsvd |          Buffer Length               |
'--------------------------------------------------------------'
```

  * 's': Transactions was setup
  * BD State:
    - `000`: Empty / Unused
    - `010`: Valid, ready for Tx/RX data
    - `011`: Valid, issue STALL (and drop data)
    - `100`: Used - Success
    - `1xx`: Used - Error with xx=01/10/11 error code


### Word 1:

```
,--------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8| 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|--------------------------------------------------------------|
|       (rsvd)      |             Buffer Pointer               |
'--------------------------------------------------------------'
```
