#include "uart_wbp_access.h"
#include <stdio.h>
#include <string.h>

void print_help(const char* argv0){
	fprintf(stderr, "usage: %s [options] <devciename> <adr> [ <dat> ]\n", argv0);
	fprintf(stderr, " options are\n");
	fprintf(stderr, " -h                : disable host response message to writes\n");
	fprintf(stderr, " -d                : disable device response message to writes\n");
	fprintf(stderr, " -s <sel>          : set select bits (default is 0xf) \n");
	fprintf(stderr, " -g <gpo>          : set general purpose output bits \n");
	fprintf(stderr, " -w <milliseconds> : wait after device access\n");
	fprintf(stderr, " -l                : listen for incoming device access, never return\n");
	fprintf(stderr, " -t <timeout>      : set stall timeout value in clock cycles\n");
	fprintf(stderr, "                     set to 0 to disable, default is 1000\n");
	fprintf(stderr, " -x                : don\'t prepend hex output with 0x verbose output\n");
	fprintf(stderr, " -v                : verbose output\n");

}

int main(int argc, char **argv) {

	const char* device_name = "";
	uint32_t device_name_set = 0;
	uint32_t adr, adr_set = 0;
	uint32_t dat, dat_set = 0;
	uint8_t  sel = 0xf;
	int timeout = 1000;
	int wait_ms = -1;
	int verbose = 0;
	int listen = 0;
	const char* zeroX = "0x";
	const char* emptystring = "";
	const char* prepend0x = zeroX;

	uint32_t gpo = 0;
	int set_gpo = 0;
	uart_wbp_config_t bridge_config = host_sends_write_response | fpga_sends_write_response;
	for (int i = 1; i < argc; ++i) {
		if (strcmp(argv[i],"--help") == 0) {
			print_help(argv[0]);
			return 0;
		} else if (strcmp(argv[i],"-h") == 0) {
			bridge_config &= ~(host_sends_write_response);
			if (verbose) {
				printf("disable host write response\n");
			}
		} else if (strcmp(argv[i],"-d") == 0) {
			bridge_config &= ~(fpga_sends_write_response);
			if (verbose) {
				printf("disable device write response\n");
			}
		} else if (strcmp(argv[i],"-t") == 0) {
			if (++i < argc) {
				sscanf(argv[i], "%d", &timeout);
				if (verbose) {
					printf("set timeout value to %d clock cycles\n", timeout);
				}
			} else {
				fprintf(stderr, "expect integer value after option -t\n");
				return -1;
			}
		} else if (strcmp(argv[i],"-s") == 0) {
			if (++i < argc) {
				sscanf(argv[i], "%hhx", &sel);
				if (sel >= 16) {
					fprintf(stderr, "expect 4-bit integer value after option -s\n");
					return -1;
				}
				if (verbose) {
					printf("set sel-bits to %x\n", sel);
				}
			} else {
				fprintf(stderr, "expect 4-bit integer value after option -s\n");
				return -1;
			}
		} else if (strcmp(argv[i],"-g") == 0) {
			if (++i < argc) {
				sscanf(argv[i], "%x", &gpo);
				if (verbose) {
					printf("set gpo-bits to %x\n", gpo);
				}
				set_gpo = 1;
			} else {
				fprintf(stderr, "expect integer value after option -s\n");
				return -1;
			}
		} else if (strcmp(argv[i],"-w") == 0) {
			if (++i < argc) {
				sscanf(argv[i], "%d", &wait_ms);
				if (verbose) {
					printf("set wait time after device access to %d ms\n", wait_ms);
				}
			} else {
				fprintf(stderr, "expect integer value after option -t\n");
				return -1;
			}
		} else if (strcmp(argv[i],"-x") == 0) {
			prepend0x = emptystring;
		} else if (strcmp(argv[i],"-v") == 0) {
			verbose = 1;
		} else if (strcmp(argv[i],"-l") == 0) {
			listen = 1;
		} else if (argv[i][0] != '-') {
			if (device_name_set == 0) {
				device_name = argv[i];
				device_name_set = 1;
			} else if (adr_set == 0) {
				sscanf(argv[i], "%x", &adr);
				adr_set = 1;
			} else if (dat_set == 0) {
				sscanf(argv[i], "%x", &dat);
				dat_set = 1;
			} else {
				fprintf(stderr, "unkown command line option: %s\n", argv[i]);
				return -1;
			}
		} else {
			fprintf(stderr, "unkown command line option: %s\n", argv[i]);
			return -1;
		}
	}

	if (!device_name_set) {
		fprintf(stderr, "missing device name\n");
		return -1;
	}
	// if (!adr_set) {
	// 	fprintf(stderr, "missing device address\n");
	// 	return -1;
	// }

	uart_wbp_device_t *device = uart_wbp_open(device_name, B2000000, verbose);
	if (!device) {
		fprintf(stderr,"cannot open device \"%s\"\n", device_name);
		return 2;
	}

	if (timeout >= 0) {
		uart_wbp_set_stall_timeout(device, timeout);
	} 
	uart_wbp_configure(device, bridge_config);

	if (set_gpo) {
		uart_wbp_set_gpo_bits(device, gpo);
	}


	if (dat_set) { // write
		uart_wbp_response_t resp = uart_wbp_write(device, sel, adr  , dat, 0, 0);
		if (verbose) {
			fprintf(stdout, "%s\n", uart_wbp_response_str(resp));
		}
	} else if (adr_set) {  // read
		uart_wbp_response_t resp = uart_wbp_read(device, sel, adr, &dat, 0, 0);
		if (verbose) {
			fprintf(stdout, "%s: dat=%s%08x\n", uart_wbp_response_str(resp), prepend0x, dat);
		} else {
			fprintf(stdout, "%s%08x\n", prepend0x, dat);
		}
	}
	if (wait_ms >= 0) {
		if (verbose) {
			printf("wait %d ms for device requests\n", wait_ms);
		}
		uart_wbp_wait(device, wait_ms);
	}
	if (listen > 0) {
		if (verbose) {
			printf("listen for incoming device requests\n");
		}
		for (;;) {
			int result = uart_wbp_wait(device, -1);
			if (result == 0) {
				break;
			}
		}
	}

	return 0;
}