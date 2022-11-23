#include "uart_wbp_access.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>

void print_help(const char* argv0){
	fprintf(stderr, "usage: %s [options] <devciename> <adr> [ <dat> ]\n", argv0);
	fprintf(stderr, " options are\n");
	fprintf(stderr, " -h                : disable host response message to writes\n");
	fprintf(stderr, " -d                : disable device response message to writes\n");
	fprintf(stderr, " -s <sel>          : set select bits (default is 0xf) \n");
	fprintf(stderr, " -g <gpo>          : set general purpose output bits \n");
	fprintf(stderr, " -w <milliseconds> : wait after device access\n");
	fprintf(stderr, " -t <timeout>      : set stall timeout value in clock cycles\n");
	fprintf(stderr, "                     set to 0 to disable, default is 1000\n");
	fprintf(stderr, " -v                : verbose output\n");
}

uint8_t handler_sel;
uint32_t handler_adr;
uint32_t handler_dat;
uart_wbp_response_t handler_response;

uint32_t get_sel_mask(uint8_t sel) {
	uint32_t sel_mask = 0;
	for (int i = 0; i < 4; ++i) {
		if (sel & (1<<i)) {
			sel_mask |= (0xff<<(i*8));
		}
	}
	return sel_mask;
}

void test_write(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t dat, uart_wbp_response_t response) {
	handler_sel = sel;
	handler_adr = adr;
	handler_dat = dat;
	handler_response = response;
	uart_wbp_response_t resp = uart_wbp_write(device, sel, adr, dat, 0, 0);
	printf("resp: %s\n", uart_wbp_response_str(resp));
	assert(resp == response);
}

void test_read(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t dat, uart_wbp_response_t response) {
	handler_sel = sel;
	handler_adr = adr;
	handler_dat = dat;
	handler_response = response;
	uint32_t data;
	uart_wbp_response_t resp = uart_wbp_read(device, sel, adr, &data, 0, 0);
	printf("resp: %s\n", uart_wbp_response_str(resp));
	assert(resp == response);
	// printf ("dat = %08x, handler_dat = %08x\n",data, handler_dat);
	uint32_t sel_mask = get_sel_mask(sel);
	assert( ((handler_dat&sel_mask) == (data&sel_mask)));
}

uart_wbp_response_t my_uart_wbp_slave_read_handler(uint8_t sel, uint32_t adr, uint32_t *dat)
{
	fprintf(stderr,"read_handler:   sel=%01x adr=%08x\n", sel, adr);
	assert(handler_sel == sel);
	assert(handler_adr == adr);
	*dat = handler_dat; 
	return handler_response;
}
uart_wbp_response_t my_uart_wbp_slave_write_handler(uint8_t sel, uint32_t adr, uint32_t dat)
{
	uint32_t sel_mask = get_sel_mask(sel);
	fprintf(stderr,"write_handler:  sel=%01x adr=%08x dat=%08x sel_mask=%08x\n", sel, adr, dat, sel_mask);
	assert(handler_sel == sel);
	assert(handler_adr == adr);
	assert((sel_mask&handler_dat) == (sel_mask&dat));
	return handler_response;
}


int main(int argc, char **argv) {
	char device_name[256];
	uint32_t device_name_set = 1;
	// uint32_t adr, adr_set = 0;
	// uint32_t dat, dat_set = 0;
	// uint8_t  sel = 0xf;
	// int timeout = 1000;
	// int wait_ms = -1;
	int verbose = 0;

	if (argc == 2) {
		strncpy(device_name, argv[1], sizeof(device_name));
	} else {
		FILE *f = fopen("/tmp/uart_chipsim_device","r");
		if (f == NULL) {
			fprintf(stderr, "cannot open /tmp/uart_chipsim_device\n");
			return -1;
		}

		fscanf(f,"%s\n",device_name);
		printf("open device: %s\n", device_name);
	}


	if (!device_name_set) {
		fprintf(stderr, "missing device name\n");
		return -1;
	}

	uart_wbp_device_t *device = uart_wbp_open(device_name, B2000000, verbose);
	if (!device) {
		fprintf(stderr,"cannot open device \"%s\"\n", device_name);
		return 2;
	}
	uart_wbp_config_t bridge_config = host_sends_write_response | fpga_sends_write_response;
	uart_wbp_configure(device, bridge_config);
	uart_wbp_set_stall_timeout(device, 50000000);

	device->write_handler = &my_uart_wbp_slave_write_handler;
	device->read_handler  = &my_uart_wbp_slave_read_handler;



	for (int i = 0; i < 2000; ++i) {
		uint8_t sel=rand()&0xf;
		uint32_t adr=rand()&0xfffffffc;
		uint32_t dat=rand();
		int x=rand()%32;
		adr &= (1<<x)-1; // truncate some upper bits of adr to have shorter addresses more often
		uart_wbp_response_t resp=ack+rand()%3;
		printf("\ndevice_setting: sel=%01x adr=%08x dat=%08x\n", device->wb_sel, device->wb_adr, device->wb_dat);
		printf("test %9d: sel=%01x adr=%08x dat=%08x, resp=%s\n", i, sel, adr, dat, uart_wbp_response_str(resp));
		if (i%2) {
			test_write(device,sel,adr,dat,resp);
		} else {
			test_read(device,sel,adr,dat,resp);
		}

	}



	return 0;
}

