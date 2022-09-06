[TOC]

# Bidirectional UART wishbone bridge

This component provides wishbone master and slave interfaces on the FPGA side and communicates with a host system over two serial UART lines.
Detailed specification of the underlying protocol will be added soon. A C-API (uart_wbp_access.h, uart_wbp_access.c) is provided that implements the underlying protocol on a Linux-System and can be used to write software that interacts with the wishbone systems on the connected FPGA.
The bridge is build in such a way that loop-back communication is possible. If the wishbone master and slave interfaces on the FPGA are connected together, the host can talk to itself through the FPGA, which facilitates integration tests of all components of the bridge.
By default, the slave and the host send responses (ack,err,rty) to the wishbone master strobes (stb). This can be disabled to increase throughput. 
The hardware slave can send a stall-timeout repsonse if the addressed slave failed to respond within a configurable amount of clock cycles. This can be useful during development.
32 gereral purpose outputs (GPOs) are available to control non-wishbone signals. For example, reset or IRQ ports of other components.

## Architecture
	                     HOST
	           |                     |
	        UART-RX               UART-TX
	           |                     |
	           |                 Serializer
	           |                     |
	        DeSerializer          UART-MUX
	           |                  |      |
	   ------SateMachine   ResponseEval  | 
	  /        |        \ /              |
	  |        |         X               |
	 GPO    WB-Master---/ \-----------WB-Slave
	  |        |                         |
	                     FPGA

## Quickstart guide

There is a vhdl testbench with a loop-back configuation of the bridge and a UART chip simulator that appears as a pseudoterminal device (/dev/pts/\<N\>, where N is an arbitrary integer). Host programs can connect to that device just as they would to a hardware serial device (e.g. /dev/ttyUSB0). 

### Run the simulation, launch host programs that interact with the simulation, and look at some traces
	cd test_loopback
	make view

This will launch gtkwave and show the wishbone signals along with the UART signals

### Run the simulation in the background and interact with it
In one terminal launch make notrace, wich will run the simulation without time limit and without writing traces. The name of the pseudoterminal device is written on the terminal as the simulation starts.
Use the host program "uart_wbp" to interact with the device. 
For example write the value 0x1234 to address 0x100 with 

	./uart_wbp /dev/pts/<N> 0x100 0x1234 

and see what happens. Since the hardware side of the bridge is configured as loop-back, the write adresses the host system, and the write callback function should be called which reports the address and the value that was written to it.
Reading works in the same way. Read from address 0x100 with 

	./uart_wbp /dev/pts/<N> 0x100 

The read callback function should be called which reports the read address.
In the terminal where the simulation is running, you can see the bytes sent from host to hardware (<< \<byte\>) and back ( >> \<byte\>). This output is generated by the UART chip simulator running within the testbench.

## UART protocol specification

This specification is for reference. As a user of the bridge you don't need to know this. Just use the provided C-API and an instantiation of the uart_wbp module.

### Host transmissions

The host can send bytes to the bridge. Generally these are interpreted as a 4-bit command in the bits [3:0] and a 4-bit payload in bits [7:4].

The following commands are defined:

| 7        | 6        | 5           | 4          | 3 | 2 | 1 | 0 | command         |
| -------- | -------- | --------    | ---------- | - | - | - | - | --------------- |
|    -     |    -     | FPGA-resp.  | host-resp. | 0 | 0 | 0 | 0 | (0) config      |
| sel(3)   | sel(2)   | sel(1)      | sel(0)     | 0 | 0 | 0 | 1 | (1) set sel     |
| sel(3)   | sel(2)   | sel(1)      | sel(0)     | 0 | 0 | 1 | 0 | (2) set dat     |
| sel(3)   | sel(2)   | sel(1)      | sel(0)     | 0 | 0 | 1 | 1 | (3) set adr     |
| keep-cyc | delta(2) | delta(1)    | delta(0)   | 0 | 1 | 0 | 0 | (4) write stb   |
| keep-cyc | delta(2) | delta(1)    | delta(0)   | 0 | 1 | 0 | 1 | (5) read stb    |
| sel(3)   | sel(2)   | sel(1)      | sel(0)     | 0 | 1 | 1 | 0 | (6) set timeout |
|    -     |    -     |    -        |    -       | 0 | 1 | 1 | 1 | (7) slave ack   |
|    -     |    -     |    -        |    -       | 1 | 0 | 0 | 0 | (8) slave err   |
|    -     |    -     |    -        |    -       | 1 | 0 | 0 | 1 | (9) slave rty   |
| sel(3)   | sel(2)   | sel(1)      | sel(0)     | 1 | 0 | 1 | 0 | (10) set gpo    |
|    -     |    -     |    -        |    -       | 1 | 0 | 1 | 1 | (11) reset      |
|    -     |    -     |    -        |    -       | 1 | 1 | 0 | 0 | (12) reserved   |
|    -     |    -     |    -        |    -       | 1 | 1 | 0 | 1 | (13) reserved   |
|    -     |    -     |    -        |    -       | 1 | 1 | 1 | 0 | (14) reserved   |
|    -     |    -     |    -        |    -       | 1 | 1 | 1 | 1 | (15) reserved   |

#### config command

If FPGA-resp.-bit is '1', the FPGA sends the response to the wishbone strobe back to the host.
If FPGA-resp.-bit is '0', no response is send an the host has no information if or how the addressed slave responded.

Wishbone responses to a strobe can be (ack, err, or rty). In addition to these, this implementation can also send a stall-timeout response when the addressed slave failed to respond within a configurable number of clock cycles. 

If the response is disabled (FPGA-resp.-bit = '0'), higher throughput can be achieved.

#### set sel command
This command has four sel-payload bits which directly set the sel-buffer register in the FPGA.
Before using a "write stb command" or a "read stb command" make sure to set the sel-buffer register, as well as the dat- and adr-buffer registers (see the following two commands).

#### set dat command
This command has four sel-payload bits which indicate which bytes of the 32-bit dat-buffer register should be written by the following bytes.
This command has to be followd by as many bytes as there are non-zero sel-payload bits.

For example if the sel-payload bits are "1111", i.e. the command byte is 0xf2, this command must be followed by four bytes containing dat[7:0], dat[15:8], dat[23:16], dat[31:24]. The bytes with lower significance are sent first. 

#### set adr command
This command has four sel-payload bits which indicate which bytes of the 32-bit adr-buffer register should be written by the following bytes.
This command has to be followd by as many bytes as there are non-zero sel-payload bits.

For example if the sel-payload bits are "1111", i.e. the command byte is 0xf3, this command must be followed by four bytes containing adr[7:0], adr[15:8], adr[23:16], adr[31:24]. The bytes with lower significance are sent first. 


#### write stb command
This command starts a wishbone write strobe in hardware. The sel-bits, adr-bits, and dat-bits of the wishbone strobe are taken from the sel-, adr-, and dat-buffer registers. These have to be set before. 

The keep-cyc-bit in the payload of this command specifies if the cycle line should be kept high after the strobe response of the addressed slave. 
This can be used to implement an atomic read-modify-write access from the host.
 - keep-cyc = '1' means that the cycle line will stay high after the strobe response.
 - keep-cyc = '0' means that the cycle line will go low after the strobe response.


The delta[2:0] bits are interpreted as a 3-bit signed integer. This value times 4 is added to the address buffer register of the bridge after the strobe response. This can be used to make faster access on a series of nearby registers without having to send an additional "set adr command".

#### read stb command
This command starts a wishbone read strobe in hardware. The sel-bits and adr-bits of the wishbone strobe are taken from the sel- and adr-buffer registers. These have to be set before. 

The keep-cyc-bit in the payload of this command specifies if the cycle line should be kept high after the strobe response of the addressed slave. 
This can be used to implement an atomic read-modify-write access from the host.
 - keep-cyc = '1' means that the cycle line will stay high after the strobe response.
 - keep-cyc = '0' means that the cycle line will go low after the strobe response.


The delta[2:0] bits are interpreted as a 3-bit signed integer. This value times 4 is added to the address buffer register of the bridge after the strobe response. This can be used to make faster access on a series of nearby registers without having to send an additional "set adr command".

#### set timeout command
This command has four sel-payload bits which indicate which bytes of the 32-bit timeout should be written by the next bytes.
This command has to be followd by as many bytes as there are non-zero sel-payload bits.

For example if the sel-payload bits are "1111", i.e. the command byte is 0xf6, this command must be followed by four bytes containing timout[7:0], timout[15:8], timout[23:16], timout[31:24]. The bytes with lower significance are sent first. 

The value in the timeout register is interpreted as an unsigned integer. If the value is 0, the timeout is disabled.
If the value is non-zero, it represents the number of clock-cycles that can pass before the bridge responds with a "stall-timeout" response. 

#### slave ack command
If the host was addressed through the wishbone slave interface of the bridge in the FPGA, this commands indicates that the bridge hardwar should respond the wishbone strobe with ack.

#### slave err command
If the host was addressed through the wishbone slave interface of the bridge in the FPGA, this commands indicates that the bridge hardwar should respond the wishbone strobe with err.

#### slave rty command
If the host was addressed through the wishbone slave interface of the bridge in the FPGA, this commands indicates that the bridge hardwar should respond the wishbone strobe with rty.

#### set gpo command
This command has four sel-payload bits which indicate which bytes of the 32-bit gpos should be written by the next bytes.
This command has to be followd by as many bytes as there are non-zero sel-payload bits.

For example if the sel-payload bits are "1010", i.e. the command byte is 0xaa, this command must be followed by two bytes containing gpo[15:8] and gpo[31:24]. The bytes with lower significance are sent first. 

#### reset command
Initiate a bridge reset. 
**This command should be sent 5 times**, because the bridge could be in a state where it expects 4 dat/adr/timeout/gpo bytes.
This should be the first command sent to the bridge before using it in order to have the hardware side of the bridge in a defined state.



### FPGA transmissions

The hardware part of the bridge on the FPGA can send bytes to the host system.
There are two main types of bytes: header-bytes and non-header bytes.
Each header-byte has the most significant bit set to '1'.
Each non-header-byte has the most significant bit set to '0'.

A message from FPGA to host always starts with a header-byte followed by variable number of non-header bytes.

A stream of bytes from the FPGA can be interpreted by skipping all non-header bytes until the first header byte appears.

### header bytes

A header byte has the most significant bit header[7] set to '1', followed by 3 bits of type information header[6:4], followd by 4 bits of payload bits header[3:0].

|  7  |   6  |   5  |   4  |   3  |   2  |   1  |   0  | type                  | payload |
|  -  |   -  |   -  |   -  |   -  |   -  |   -  |   -  | ----                  | --------|
| '1' |  '0' |  '0' |  '0' |  '0' |  '0' |  '0' |  '1' | (0) write response    | (1) write ack | 
| '1' |  '0' |  '0' |  '0' |  '0' |  '0' |  '1' |  '0' | (0) write response    | (2) write err | 
| '1' |  '0' |  '0' |  '0' |  '0' |  '0' |  '1' |  '1' | (0) write response    | (3) write rty | 
| '1' |  '0' |  '0' |  '0' |  '0' |  '1' |  '0' |  '0' | (0) write response    | (4) write stall timeout | 
| '1' |  '0' |  '0' |  '1' | dat(31) | dat(23) | dat(15) | dat(7) | (1) read response ack | MSB of the following data bytes | 
| '1' |  '0' |  '1' |  '0' | dat(31) | dat(23) | dat(15) | dat(7) | (2) read response err | MSB of the following data bytes | 
| '1' |  '0' |  '1' |  '1' | dat(31) | dat(23) | dat(15) | dat(7) | (3) read response rty | MSB of the following data bytes | 
| '1' |  '1' |  '0' |  '0' | - | - | - | - | (4) read response stall timeout | MSB of the following data bytes | 
| '1' |  '1' |  '0' |  '1' | sel(3) | sel(2) | sel(1) | sel(0) | (5) write request | sel-bits of wishbone write | 
| '1' |  '1' |  '1' |  '0' | - | - | - | - | (6) reserved | - | 
| '1' |  '1' |  '1' |  '0' | sel(3) | sel(2) | sel(1) | sel(0) | (7) read request | sel-bits of wishbone write | 
| '1' |  '1' |  '1' |  '1' | - | - | - | - | (8) reserved | - | 


#### write response

The write response header has 0 in the type field and is sent in response to a wishbone write strobe from the host. This happens only if the bridge is configured to send write responses (see host transmissong config command). The response type (ack,err,rty,stall timeout) in the payload field.

#### read response ack

The read response ack header has 1 in the type field and is sent in response to a wishbone read strobe from the host that was anwered with ack. 
The payload field contains the four MSB of the data that comes in the following bytes. (The following bytes are non header bytes (bit(7) is '0'), so each byte carries only 7 bit of information.)

#### read response err

The read response err header has 2 in the type field and is sent in response to a wishbone read strobe from the host that was anwered with err. 
The payload field contains the four MSB of the data that comes in the following bytes. (The following bytes are non header bytes (bit(7) is '0'), so each byte carries only 7 bit of information.) In case of an err read response the data is most likely meaningless, but the bridge delivers the dat information nontheless.

#### read response rty

The read response rty header has 3 in the type field and is sent in response to a wishbone read strobe from the host that was anwered with rty. 
The payload field contains the four MSB of the data that comes in the following bytes. (The following bytes are non header bytes (bit(7) is '0'), so each byte carries only 7 bit of information.) In case of an rty read response the data is most likely meaningless, but the bridge delivers the dat information nontheless.

#### read response stall timeout

The read response stall timeout header has 4 in the type field and is sent in response to a wishbone read strobe from the host that was not answered after timeout clock cycles (see host transmission set timeout comand). 
The payload field contains the four MSB of the data that comes in the following bytes. (The following bytes are non header bytes (bit(7) is '0'), so each byte carries only 7 bit of information.) In case of a stall timeout read response the data is most likely meaningless, but the bridge delivers the dat information nontheless.

#### write request header

This header is sent if a wishbone master adressed the wishbone slave interface of the bridge with a write strobe.
It contains a 5 in the type field and has the sel bits of the wishbone strobe in the payload field.

It is followed by at leas 1 and at most 10 non-header bytes.

The first following non-header byte looks like this:

|  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
|  -  |  -  |  -  |  -  |  -  |  -  |  -  |  -  |
| '0' | more-adr-bits | adr(3) | adr(2) | dat(31) | dat(23) | dat(15) | dat(7) |

If more-adr-bits = '0', no more non-header bytes with address information will follow.
If more-adr-bits = '1', more non-header bytes with address information will follow.

These additional address information look like this 

|  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
|  -  |  -  |  -  |  -  |  -  |  -  |  -  |  -  |
| '0' | more-adr-bits | adr(x+6) | adr(x+5) | adr(x+4) | adr(x+3) | adr(x+2) | adr(x+1) |

Where x is the most significant address-bit of the adr field send with the previous byte.
If more-adr-bits = '1', more non-header bytes with address information will follow.
If more-adr-bits = '0', no more non-header bytes with address information will follow.

The last non-header byte with address information is followed by zero to four non-header bytes with data information. The number of bytes is equal to the number of non-zero sel-bits in the write request header. Each data byte looks like this

|  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
|  -  |  -  |  -  |  -  |  -  |  -  |  -  |  -  |
| '0' | dat(i*8+6) | dat(i*8+5) | dat(i*8+4) | dat(i*8+3) | dat(i*8+2) | dat(i*8+1) | dat(i*8+0) |

where is the index of a non-zero sel-bit.
The data  bytes are sent least significant byte first.


Example of write request with up to 4 address-bits (adr[0] and adr[1] are always '0') and 4 data bytes (sel="1111") 

	   header      
	"1 101 1111" "00aadddd" "0ddddddd" "0ddddddd" "0ddddddd" "0dddddddd"
	               |||        |     |    |     |    |     |    |      |
	               ||adr[2]   |   dat[0] |  dat[8]  | dat[16]  |   dat[24]
	               |adr[3]    dat[6]     dat[14]    dat[22]    dat[30]
                   no more adr information follows

Example of write request with up to 10 address-bits (adr[0] and adr[1] are always '0') and 3 data bytes (sel="0111") 

	   header      
	"1 101 0111" "01aadddd" "00aaaaaa" "0ddddddd" "0ddddddd" "0ddddddd" 
	       sel     |||         |    |    |     |    |     |    |     |   
	               ||adr[2]    | adr[4]  |   dat[0] |  dat[8]  |  dat[16]
	               |adr[3]   adr[9]      dat[6]     dat[14]    dat[22]   
                   more adr information follows

#### write request header

Same as read request header, only that the type is 7 instead of 5, and there are no data bytes and the first non-header byte after the header has 6 address bits instead of 2 address bits and 4 data bits.

Example of read request with up to 8 address-bits (adr[0] and adr[1] are always '0') and 4 data bytes (sel="1111")

	   header      
	"1 101 1111" "00aaaaaa"
	       sel     ||    | 
	               ||  adr[2]
	               |adr[7]   
                   no more adr information follows

Example of read request with up to 32 address-bits (adr[0] and adr[1] are always '0') and 4 data bytes (sel="1111")

	   header      
	"1 101 1111" "01aaaaaa" "01aaaaaa" "01aaaaaa" "01aaaaaa" "00aaaaaa"  
	       sel     ||    |     |    |     |    |     |    |    ||    |   
	               ||  adr[2]  |  adr[8]  |  adr[14] | adr[20] ||  adr[26]
	               |adr[7]     adr[13]    adr[19]    adr[25]   |adr[31]   
                   more adr information follows                no more adr information follows