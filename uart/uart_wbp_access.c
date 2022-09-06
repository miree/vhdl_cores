#include "uart_wbp_access.h"

// POSIX header
#include <termios.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <poll.h>
// C header
#include <stdio.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

char *see_speed(speed_t speed) {
  static char   SPEED[20];
  switch (speed) {
    case B0:       strcpy(SPEED, "B0");
                   break;
    case B50:      strcpy(SPEED, "B50");
                   break;
    case B75:      strcpy(SPEED, "B75");
                   break;
    case B110:     strcpy(SPEED, "B110");
                   break;
    case B134:     strcpy(SPEED, "B134");
                   break;
    case B150:     strcpy(SPEED, "B150");
                   break;
    case B200:     strcpy(SPEED, "B200");
                   break;
    case B300:     strcpy(SPEED, "B300");
                   break;
    case B600:     strcpy(SPEED, "B600");
                   break;
    case B1200:    strcpy(SPEED, "B1200");
                   break;
    case B1800:    strcpy(SPEED, "B1800");
                   break;
    case B2400:    strcpy(SPEED, "B2400");
                   break;
    case B4800:    strcpy(SPEED, "B4800");
                   break;
    case B9600:    strcpy(SPEED, "B9600");
                   break;
    case B19200:   strcpy(SPEED, "B19200");
                   break;
    case B38400:   strcpy(SPEED, "B38400");
                   break;
    case B57600:   strcpy(SPEED, "B57600");
                   break;
    case B115200:  strcpy(SPEED, "B115200");
                   break;
    case B230400:  strcpy(SPEED, "B230400");
                   break;
    case B460800:  strcpy(SPEED, "B460800");
                   break;
    case B500000:  strcpy(SPEED, "B500000");
                   break;
    case B576000:  strcpy(SPEED, "B576000");
                   break;
    case B921600:  strcpy(SPEED, "B921600");
                   break;
    case B1000000: strcpy(SPEED, "B1000000");
                   break;
    case B1152000: strcpy(SPEED, "B1152000");
                   break;
    case B1500000: strcpy(SPEED, "B1500000");
                   break;
    case B2000000: strcpy(SPEED, "B2000000");
                   break;
    default:       sprintf(SPEED, "unknown (%d)", (int) speed);
  }
  return SPEED;
}

enum uart_wbp_master_commands {
	uart_wbp_master_command_config      = 0,
	uart_wbp_master_command_set_sel     = 1,
	uart_wbp_master_command_set_dat     = 2,
	uart_wbp_master_command_set_adr     = 3,
	uart_wbp_master_command_write_stb   = 4,
	uart_wbp_master_command_read_stb    = 5,
	uart_wbp_master_command_set_timeout = 6,	
	uart_wbp_master_response_ack        = 7,	
	uart_wbp_master_response_err        = 8,	
	uart_wbp_master_response_rty        = 9,	
	uart_wbp_master_command_set_gpo_bits=10,
	uart_wbp_master_command_reset       =11,
};

int reset_bridge_state(uart_wbp_device_t *device) {
	uint8_t cmd_rst = uart_wbp_master_command_reset;
	uint8_t reset_msg[] = {cmd_rst, cmd_rst, cmd_rst, cmd_rst, cmd_rst };
	if (write(device->fd, reset_msg, sizeof(reset_msg)) != sizeof(reset_msg)) {
		return -1;
	};

	// reset the variables that represent the hardware state
	device->wb_dat    = 0x0;
	device->wb_adr    = 0x0;
	device->wb_sel    = 0x0;
	device->hw_config = host_sends_write_response | fpga_sends_write_response;

	return 0;
}

uart_wbp_response_t uart_wbp_slave_default_write_handler(uint8_t sel, uint32_t adr, uint32_t dat) {
	printf("uart_wbp_slave_default_write_handler: sel=0x%x adr=0x%08x dat=0x%08x\n", sel, adr, dat);
	return ack;
}
uart_wbp_response_t uart_wbp_slave_default_read_handler(uint8_t sel, uint32_t adr, uint32_t *dat) {
	printf("uart_wbp_slave_default_read_handler: sel=0x%x adr=0x%08x\n", sel, adr);
	*dat = 0xab12affe;
	return ack;
}


uart_wbp_device_t* uart_wbp_open(const char* device_name, speed_t speed, int verbose)
{
	int fd = open(device_name, O_RDWR);// | O_NONBLOCK);
	if (fd == -1) {
		return NULL;
	}
	// put fd in raw mode
    struct termios raw;
	if (tcgetattr(fd, &raw) == 0)
	{
		cfsetspeed(&raw, speed);
		// input modes - clear indicated ones giving: no break, no CR to NL, 
		//   no parity check, no strip char, no start/stop output (sic) control 
		raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
		// output modes - clear giving: no post processing such as NL to CR+NL 
		raw.c_oflag &= ~(OPOST);
		// control modes - set 8 bit chars 
		raw.c_cflag |= (CS8);
		// local modes - clear giving: echoing off, canonical off (no erase with 
		//   backspace, ^U,...),  no extended functions, no signal chars (^Z,^C) 
		raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
		// control chars - set return condition: min number of bytes and timer 
		raw.c_cc[VMIN] = 1; raw.c_cc[VTIME] = 0; // after two bytes, no timer 
		// put terminal in raw mode after flushing 
		if (tcsetattr(fd,TCSAFLUSH,&raw) < 0) 
		{
			int err = errno;
			printf("Error, cant set raw mode: %s\n", strerror(err));
			return NULL;
		}

		if (verbose) {
			speed_t speed = cfgetispeed(&raw);
			printf("speed: %s\n", see_speed(speed));
		}
	}


	uart_wbp_device_t *device = (uart_wbp_device_t*)malloc(sizeof(uart_wbp_device_t));
	if (device == NULL) {
		close(fd);
		return NULL;
	}

	device->fd = fd;

	// // read all incoming bytes util empty
	// for (;;) {
	// 	struct pollfd pfd[1];
	// 	pfd[0].events = POLLIN;
	// 	int result = poll(pfd,1,0); // poll with timeout of 0;
	// 	if (result == 0) break; // timout was hit -> nothing to read
	// 	char ch;
	// 	if (read(device->fd, &ch, 1) != 1) break;
	// }


	// put hardware side of the bridge into a known state
	if (reset_bridge_state(device) < 0) {
		fprintf(stderr, "cannot write to device\n");
		close(fd);
		return NULL;
	}

	// initialize the readbuffer;
	device->buffer_top_idx  = 0;
	device->buffer_read_idx = 0;

	device->write_handler = uart_wbp_slave_default_write_handler;
	device->read_handler  = uart_wbp_slave_default_read_handler;


	return device;
}

void uart_wbp_close(uart_wbp_device_t *device)
{
	if (device->fd != -1) {
		close(device->fd);
	}
	free(device);
	device = NULL;
}

int uart_wbp_buffered_read(uart_wbp_device_t *device, uint8_t *dat) {
	if (device->buffer_read_idx >= device->buffer_top_idx) {
		device->buffer_read_idx = 0; //reset the buffer read index and read as much data as is available
		int result = read(device->fd, &device->buffer[0], UART_WBP_BUFFER_SIZE);
		// printf("read returned %d\n", device->buffer_top_idx);
		if (result <= 0) {
			return -1;
		}
		device->buffer_top_idx = result;
	}
	// printf("buffered_read idx = %d dat = %x\n", device->buffer_read_idx, (unsigned)dat);
	*dat = device->buffer[device->buffer_read_idx++];
	return 0;
}

int uart_wbp_handle_slave_write(uart_wbp_device_t *device, uint8_t header) {
	uint8_t sel = header&0x0f;

	// build address
	uint32_t adr = 0x0;
	// read 2nd header (0naadddd)  ; n='1' more address bytes will follow, aa=lsb of address, dddd msb of following data bytes
	uint8_t header2;
	if (uart_wbp_buffered_read(device, &header2) < 0) {
		fprintf(stderr, "Error reading from device\n");
		return -1;
	}
	uint8_t byte_msb = header2 & 0x0f; // store the most significant bits of the data bytes
	adr = ((header2 & 0x30)>>2);
	int shift = 4;
	while (header2 & 0x40) {
		// more address bits (0naaaaaa)
		if (uart_wbp_buffered_read(device, &header2) < 0) {
			fprintf(stderr, "Error reading from device\n");
			return -1;
		}
		adr |= (header2 & 0x3f)<<shift;
		shift += 6;
	}
	// printf("adr = %08x\n", adr);
	// build data
	uint32_t dat = 0;
	for (int i = 0; i < 4; ++i) {
		uint8_t data_byte;
		if (sel&(1<<i)) {
			if (uart_wbp_buffered_read(device, &data_byte) < 0) {
				fprintf(stderr, "Error reading from device\n");
				return -1;
			}
			if (byte_msb&(1<<i)) {
				data_byte |= 0x80;
			}
			dat |= (data_byte<<(8*i));
		}
	}
	// printf("dat = %08x\n", dat);
	int response = device->write_handler(sel, adr, dat);
	if (device->hw_config & host_sends_write_response) {
		// printf("host_sends_write_response is true, send response %d\n", response);
		// send repsone 
		//uart_wbp_master_response_ack
		uint8_t msg;
		int result;
		switch(response) {
			case ack:
				msg = uart_wbp_master_response_ack;
				// printf("write response is ack\n");
				result = write(device->fd, &msg, 1);
			break;
			case err:
				msg = uart_wbp_master_response_err;
				// printf("write response is err\n");
				result = write(device->fd, &msg, 1);
				break;
			case rty:
				msg = uart_wbp_master_response_rty;
				// printf("write response is rty\n");
				result = write(device->fd, &msg, 1);
				break;
			default:
				msg = uart_wbp_master_response_err;
				// printf("write response is unknonw -> send err\n");
				result = write(device->fd, &msg, 1);
				break;
		}
		if (result != 1) {
			printf("Error: cannot send write response\n");
			return -1;
		}
	}
	return 0;
}


int uart_wbp_handle_slave_read(uart_wbp_device_t *device, uint8_t header) {
	uint8_t sel = header&0x0f;

	// build address
	uint32_t adr = 0x0;
	uint8_t adr_byte;
	int shift = 2;
	for(;;) {
		// more address bits (0naaaaaa)
		if (uart_wbp_buffered_read(device, &adr_byte) < 0) {
			fprintf(stderr, "Error reading from device\n");
			return -1;
		}
		// printf("adr_byte = %02x\n",adr_byte);
		adr |= ((uint32_t)(adr_byte & 0x3f))<<shift;
		if (!(adr_byte & 0x40)) {
			break;
		}
		shift += 6;
	}
	// printf("adr = %08x\n", adr);

	uint32_t dat;
	int response = device->read_handler(sel, adr, &dat);
	// printf("host sends read response %d\n", response);
	// send repsone 
	// first set wb_dat in hardware
	uint8_t read_response_msg[12];
	int read_response_msg_len = 0;
	// write only those bytes of the data that are different from the buffered data bytes and covered by the sel bits
	int dat_sel_idx = read_response_msg_len;
	read_response_msg[dat_sel_idx] = uart_wbp_master_command_set_dat ; 
	int i;
	for (i = 0; i < 4; ++i) {
		if ((device->wb_dat&(0x000000ff<<(8*i))) != (dat&(0x000000ff)<<(8*i)) && (sel&(0x1<<(i)))) {
			read_response_msg[dat_sel_idx] |= (0x10<<i);
			read_response_msg[++read_response_msg_len] = (dat>>(8*i))&0x000000ff;
		}
	}
	// put the write-stb command into the buffer, if there was no dat byte set, the set dat sel-bits command can be overwriitten
	if (read_response_msg_len > dat_sel_idx) {
		++read_response_msg_len; 
	} 
	switch(response) {
		case ack:
			read_response_msg[read_response_msg_len++] = uart_wbp_master_response_ack;
		break;
		case err:
			read_response_msg[read_response_msg_len++] = uart_wbp_master_response_err;
		break;
		case rty:
			read_response_msg[read_response_msg_len++] = uart_wbp_master_response_rty;
		break;
	}
	// printf("writing the message (%d bytes) to bridge\n", read_response_msg_len);
	if (write(device->fd, read_response_msg, read_response_msg_len) != read_response_msg_len) {
		return -1;
	};
	// update hardware representation
	for (int i = 0; i < 4; ++i) {
		if (sel & (1<<i)) {
			device->wb_dat &= ~(0xff<<(i*8));
			device->wb_dat |=  (0xff<<(i*8)) & dat;
		}
	}
	return 0;
}


// hardware access helper functions
int uart_wbp_read_header(uart_wbp_device_t *device, uint8_t *header, int expect_rw) {
	for (;;) {
		
		for (;;) {
			if (uart_wbp_buffered_read(device, header) < 0) {
				fprintf(stderr, "Error reading from device\n");
				return -1;
			}
			if (*header & 0x80) break;
			// else skip unexpected byte
			fprintf(stderr, "Skipping unexpected non-header byte %02x\n", *header);
			// assert(0);
		}
		uart_wbp_response_t response_type = ((*header >> 4)&0x7);
		uart_wbp_response_t write_response_type = ((*header)&0x7); // write response header encodes response type in 3 LSB
		switch(response_type) {
			case write_response: 
				switch (write_response_type) {
					case ack:
						// printf("got write response ack\n");
						return 0;
					case err:
						// printf("got write response err\n");
						return 0;
					case rty:
						// printf("got write response rty\n");
						return 0;
					case stall_timeout:
						// printf("got write response stall_timeout\n");
						return 0;
					default:
						return -1;				
				}     
				break;
			case ack:
				// printf("got read response ack\n");
				return 0;
			case err:
				// printf("got read response err\n");
				return 0;
			case rty:
				// printf("got read response rty\n");
				return 0;
			case stall_timeout:
				// printf("got read response stall_timeout\n");
				return 0;
			case write_request:
				// printf("the slave intefcace was written to\n");
				uart_wbp_handle_slave_write(device, *header);
				if (expect_rw) {
					return 0;
				}
				break;
			case read_request:
				// printf("the slave inteface was read from\n");
				uart_wbp_handle_slave_read(device, *header);
				if (expect_rw) {
					return 0;
				}
				break;
			default:
				return -1;
		}
	}

	return 0;
}

// public hardware access functions
const char* uart_wbp_response_str(uart_wbp_response_t response)
{
	switch (response) {
		case write_response: return "write_response";
		case ack: return "ack";
		case err: return "err";
		case rty: return "rty";
		case stall_timeout: return "stall_timeout";
		case write_request: return "write_request";
		case read_request: return "read_request";
		case unknown: return "unknown (response deactivated)";
		default: return "unkonwn (something went wrong)";
	}
	return "";
}

void uart_wbp_set_stall_timeout(uart_wbp_device_t *device, int timeout)
{
	uint8_t msg[5] = {uart_wbp_master_command_set_timeout | 0xf0,
	                  (timeout>>0), (timeout>>8), (timeout>>16), (timeout>>24)};
	int len = 5;
	//printf("set stall timeout to %d\n", timeout);
	int result = write(device->fd, msg, len);
	assert(result == len);
}

void uart_wbp_configure(uart_wbp_device_t *device, uart_wbp_config_t flags)
{
	uint8_t msg = uart_wbp_master_command_config | (flags << 4);
	int result = write(device->fd, &msg, 1);
	assert(result == 1);
	device->hw_config = flags;
}

void uart_wbp_set_gpo_bits(uart_wbp_device_t *device, uint32_t bits)
{
	uint8_t msg[5] = {uart_wbp_master_command_set_gpo_bits | 0xf0,
	                  (bits>>0), (bits>>8), (bits>>16), (bits>>24)};
	int len = 5;
	int result = write(device->fd, msg, len);
	assert(result == len);	
}


uart_wbp_response_t uart_wbp_write(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t dat, int delta_adr, int keep_cyc) 
{
	delta_adr /= 4;
	if (delta_adr > 3  || delta_adr < -4) {
		printf("delta_adr is out of bounds [-16,12]");
		return -1;
	}
	delta_adr &= 0x00000007;

	// any nonzero value of keep_cyc will do
	if (keep_cyc) {
		keep_cyc = 0x8;
	}

	uint8_t write_stb_msg[12];
	int write_stb_msg_len = 0;
	// change the sel bits of the hardware only if they are different than what is requested
	if (device->wb_sel != sel) {
		write_stb_msg[write_stb_msg_len++] = uart_wbp_master_command_set_sel | (sel<<4); 
	}
	// write only those bytes of the data that are different from the buffered data bytes and covered by the sel bits
	int dat_sel_idx = write_stb_msg_len;
	write_stb_msg[dat_sel_idx] = uart_wbp_master_command_set_dat ; 
	int i;
	for (i = 0; i < 4; ++i) {
		if ((device->wb_dat&(0x000000ff<<(8*i))) != (dat&(0x000000ff)<<(8*i)) && (sel&(0x1<<(i)))) {
			write_stb_msg[dat_sel_idx] |= (0x10<<i);
			write_stb_msg[++write_stb_msg_len] = (dat>>(8*i))&0x000000ff;
		}
	}
	// put the write-stb command into the buffer, if there was no dat byte set, the set dat sel-bits command can be overwriitten
	if (write_stb_msg_len > dat_sel_idx) {
		++write_stb_msg_len; 
	} 
	// write only those bytes of the address that are different from the buffered address bytes
	int adr_sel_idx = write_stb_msg_len;
	//printf("buffer adr=%08x  requested adr=%08x \n", device->wb_adr, adr);
	write_stb_msg[adr_sel_idx] = uart_wbp_master_command_set_adr ; 
	for (i = 0; i < 4; ++i) {
		if ((device->wb_adr&(0x000000ff<<(8*i))) != (adr&(0x000000ff)<<(8*i))) {
			write_stb_msg[adr_sel_idx] |= (0x10<<i);
			write_stb_msg[++write_stb_msg_len] = (adr>>(8*i))&0x000000ff;
		}
	}
	// put the write-stb command into the buffer, if there was no adr byte set, the set adr sel-bits command can be overwriitten
	if (write_stb_msg_len > adr_sel_idx) {
		++write_stb_msg_len; 
	} 
	write_stb_msg[write_stb_msg_len++] = uart_wbp_master_command_write_stb | ((keep_cyc | delta_adr)<<4);
	//printf("writing the message (%d bytes) to bridge\n", write_stb_msg_len);
	if (write(device->fd, write_stb_msg, write_stb_msg_len) != write_stb_msg_len) {
		return -1;
	};

	// now that the data is written to the hardware, update 
	// our representation of the hardware state
	device->wb_sel = sel;
	device->wb_adr = adr+4*delta_adr;
	for (int i = 0; i < 4; ++i) {
		if (sel & (1<<i)) {
			device->wb_dat &= ~(0xff<<(i*8));
			device->wb_dat |=  (0xff<<(i*8)) & dat;
		}
	}

	if (device->hw_config & fpga_sends_write_response) {
		uint8_t header;
		//printf("read the response header\n");
		for (;;) {
			if (uart_wbp_read_header(device, &header, 0) < 0) {
				fprintf(stderr, "Error reading reponse\n");
			}
			if (((header & 0x70)>>4) == write_response) {
				uart_wbp_response_t response_type = (header & 0x7);
				if (response_type == ack) {
					// printf("write: ack received\n");
				} else if (response_type == err) {
					// printf("write: err received\n");
				} else if (response_type == rty) {
					// printf("write: rty received\n");
				} else if (response_type == stall_timeout) {
					// printf("write: stall_timeout received\n");
				}
				return response_type;
				break;
			}
		}

	} else {
		// printf("write response from hardware is disabled\n");
		return unknown;
	}
	return err;
}



uart_wbp_response_t uart_wbp_read(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t *dat, int delta_adr, int keep_cyc) {

	delta_adr /= 4;
	if (delta_adr > 3  || delta_adr < -4) {
		printf("uart_wbp_read:delta_adr is out of bounds [-16,12]");
		return -1;
	}
	delta_adr &= 0x00000007;

	// any nonzero value of keep_cyc will cause that cyc will stay high after stb response
	if (keep_cyc) {
		keep_cyc = 0x8;
	}

	// the more complicated but possibly more efficient way of making a wishbone write in the hardware
	uint8_t read_stb_msg[12];
	int read_stb_msg_len = 0;
	// change the sel bits of the hardware only if they are different than what is requested
	if (device->wb_sel != sel) {
		read_stb_msg[read_stb_msg_len++] = uart_wbp_master_command_set_sel | (sel<<4); 
		device->wb_sel = sel;
	}

	// write only those bytes of the address that are different from the buffered address bytes
	int adr_sel_idx = read_stb_msg_len;
	// printf("uart_wbp_read:  requested adr=%08x \n", device->wb_adr, adr);
	read_stb_msg[adr_sel_idx] = uart_wbp_master_command_set_adr ; 
	int i;
	for (i = 0; i < 4; ++i) {
		if ((device->wb_adr&(0x000000ff<<(8*i))) != (adr&(0x000000ff)<<(8*i))) {
			read_stb_msg[adr_sel_idx] |= (0x10<<i);
			read_stb_msg[++read_stb_msg_len] = (adr>>(8*i))&0x000000ff;
		}
	}
	// put the write-stb command into the buffer, if there was no adr byte set, the set adr sel-bits command can be overwriitten
	if (read_stb_msg_len > adr_sel_idx) {
		++read_stb_msg_len; 
	} 
	read_stb_msg[read_stb_msg_len++] = uart_wbp_master_command_read_stb | ((keep_cyc | delta_adr)<<4);
	// printf("uart_wbp_read: writing the message (%d bytes) to bridge\n", read_stb_msg_len);
	if (write(device->fd, read_stb_msg, read_stb_msg_len) != read_stb_msg_len) {
		fprintf(stderr, "uart_wbp_read: Error writing data to hardware\n");
		return -1;
	};

	// now that the data is written to the hardware, update 
	// our representation of the hardware state
	device->wb_sel = sel;
	device->wb_adr = adr+4*delta_adr;


	uint8_t header;
	// printf("uart_wbp_read: read the response header\n");
	for (;;) {
		if (uart_wbp_read_header(device, &header, 0) < 0) {
			fprintf(stderr, "uart_wbp_read: Error reading reponse\n");
		}
		// printf("uart_wbp_read: got header %02x\n", header);
		uart_wbp_response_t response_type = ((header & 0x70)>>4);
		if (response_type == write_response) {
			fprintf(stderr, "uart_wbp_read: Error: expect read response, got write response\n");
		} else if (response_type == ack || response_type == err || response_type == rty || response_type == stall_timeout) {
			// build the data word
			// printf("uart_wbp_read: got read response %d\n", response_type);
			*dat = 0;
			if (header&1) *dat |= (1<< 7); 
			if (header&2) *dat |= (1<<15); 
			if (header&4) *dat |= (1<<23); 
			if (header&8) *dat |= (1<<31); 
			for (int i = 0; i < 4; ++i) {
				if (sel&(1<<i)) {
					uint8_t data_byte;
					if (uart_wbp_buffered_read(device, &data_byte) < 0) {
						fprintf(stderr, "Error reading from device\n");
						return -1;
					} else {
						*dat |= (((uint32_t)data_byte)<<(8*i));				
					}
				}
			}
		}
		return response_type;
	}

	return err;
}

int uart_wbp_wait_single(uart_wbp_device_t *device, int timeout)
{
	struct pollfd pfd[1];
	pfd[0].fd = device->fd;
	pfd[0].events = POLLIN;
	int result = poll(pfd, 1, timeout);
	if (result > 0) {
		if (pfd[0].revents & POLLHUP || pfd[0].revents & POLLERR || pfd[0].revents & POLLNVAL) {
			fprintf(stderr, "device disconnected\n");
			return -1; // error
		}
		if (pfd[0].revents & POLLIN) {
			uint8_t header;
			if (uart_wbp_read_header(device, &header, 1) < 0) {
				fprintf(stderr, "Error: cannot read header\n");
				return -1; // error
			}
		} else {
			fprintf(stderr, "cannot read from file descriptor\n");
			return -1; // error
		}
		return result;
	} 
	// else if (result == 0) {
	// 	if (timeout > 0) {
	// 		printf("uart_wbp_wait: timeout\n");
	// 	} else {
	// 		printf("uart_wbp_wait: nothing there\n");
	// 	}
	// } 
	return result;
}

int uart_wbp_wait(uart_wbp_device_t *device, int timeout)
{
	int result = uart_wbp_wait_single(device, timeout);
	if (result > 0) {
		while(uart_wbp_wait_single(device, 0) > 0);
	}
	return result;
}

