HyperRAM controller Registers
=============================


FIXME: Document the manual command submission for link training


Control
-------

### Control / Status (Read / Write addr `0x00`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|               /             |phase| phy_delay |  cap_lat  |  cmd_lat  |     /     |ir|ic|rs|ru|
'-----------------------------------------------------------------------------------------------'

 * [21:20] - phy_phase : PHY config - Phase select
 * [19:16] - phy_delay : PHY config - Delay select
 * [15:12] - cap_lat   : Capture latency
 * [11: 8] - cmd_lat   : Command latency
 * [    3] - ir        : Idle 'run' mode
 * [    2] - ic        : Idle 'config' mode
 * [    1] - rs        : Reset
 * [    0] - ru        : Running
```


### Command Execute (Write only addr `0x01`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|                             /                             |    len    |    lat    |  /  |as|rw|
'-----------------------------------------------------------------------------------------------'

 * [11: 8] - len : Length ( # of xfer - 1 )
 * [ 7: 4] - lat : Latency counter
 * [ 3: 2] - cs  : Chip Select
 * [    1] - as  : Memory (0) / Register (1)
 * [    0] - rw  : Write  (0) / Read     (1)
```


Word Queue Write
----------------

To put a word in the queue, write the attributes first, then write the
corresponding data word. The write to the data register will trigger the
queuing with whatever attributes were last set.

The newly written word will always end up in last position (pos=2) and the
words that were previously in positions 1 & 2 will be in position 0 & 1.


### Word Enqueue - Data (Write only addr `0x02`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|                                              data                                             |
'-----------------------------------------------------------------------------------------------'

 * [31: 0] - data : Data word to queue
```


### Word Enqueue - Attributes (Write only addr `0x03`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|                                           /                                 |  oe |   rwds    |
'-----------------------------------------------------------------------------------------------'

 * [ 5: 4] - oe   : Output Enable (per 16 bits)
 * [ 3: 0] - rwds : RWDS value     (per 8 bits)
```


Word Queue Read
---------------

To read a word from the queue, read the attributes first to get the RWDS
values and then read the corresponding data word. The read of the data
register will trigger the de-queuing.

The words that is read is the one that was first, at position 0 in the queue.
The words that were previously in positions 1 & 2 will be moved up to
positions 0 & 1.


### Word Dequeue - Data (Read only addr `0x02`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|                                              data                                             |
'-----------------------------------------------------------------------------------------------'

 * [31: 0] - data : Data word to queue
```


### Word Dequeue - Attributes (Read only addr `0x03`)

```text
,-----------------------------------------------------------------------------------------------,
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10| 9| 8| 7| 6| 5| 4| 3| 2| 1| 0|
|-----------------------------------------------------------------------------------------------|
|                                             /                                     |   rwds    |
'-----------------------------------------------------------------------------------------------'

 * [ 3: 0] - rwds : RWDS value     (per 8 bits)
```
