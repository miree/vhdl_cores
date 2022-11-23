#ifndef UART_WBP_ACCESS_H_
#define UART_WBP_ACCESS_H_

#include <termios.h>
#include <unistd.h>
#include <stdint.h>

typedef enum uart_wbp_response {
	write_response  = 0,
	ack             = 1,
	err             = 2,
	rty             = 3,
	stall_timeout   = 4,
	write_request   = 5, // 101
	write_req_norsp = 6, // 110
	read_request    = 7, // 111
	// if write response is disabled, unknown is returned
	unknown        = 8, 
} uart_wbp_response_t;

const char* uart_wbp_response_str(uart_wbp_response_t response);

// flags to configure the bridge behavior
typedef enum uart_wbp_config {
	host_sends_write_response = 1,
	fpga_sends_write_response = 2,
	// ..                     = 4,
	// ..                     = 8,
} uart_wbp_config_t;

typedef uart_wbp_response_t (*uart_wbp_slave_write_handler_f)(uint8_t sel, uint32_t adr, uint32_t dat);
typedef uart_wbp_response_t (*uart_wbp_slave_read_handler_f)(uint8_t sel, uint32_t adr, uint32_t *dat);

#define UART_WBP_BUFFER_SIZE 256
typedef struct uart_wbp_device
{
	// the file descriptor to read/write the device
	int fd;
	
	// the internal state of the hardware bridge
	uint32_t wb_dat;
	uint32_t wb_adr;
	uint8_t  wb_sel;
	uart_wbp_config_t  hw_config;
	
	// a ringbuffer for incoming data
	uint8_t  buffer[UART_WBP_BUFFER_SIZE];
	uint32_t buffer_top_idx;    // buffer contains valid data until this index
	uint32_t buffer_read_idx;   // read index into the buffer

	// callbacks for when the slave is accessed
	uart_wbp_slave_write_handler_f write_handler;
	uart_wbp_slave_read_handler_f  read_handler;

} uart_wbp_device_t;

uart_wbp_device_t* uart_wbp_open(const char* device_name, speed_t speed, int verbose);
void               uart_wbp_close(uart_wbp_device_t *device);

void uart_wbp_set_stall_timeout(uart_wbp_device_t *device, int timeout);
void uart_wbp_configure(uart_wbp_device_t *device, uart_wbp_config_t flags);
void uart_wbp_set_gpo_bits(uart_wbp_device_t *device, uint32_t bits);

uart_wbp_response_t uart_wbp_write(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t dat, int delta_adr, int keep_cyc);
uart_wbp_response_t uart_wbp_read(uart_wbp_device_t *device, uint8_t sel, uint32_t adr, uint32_t *dat, int delta_adr, int keep_cyc);

int uart_wbp_wait_single(uart_wbp_device_t *device, int timeout);
int uart_wbp_wait(uart_wbp_device_t *device, int timeout);

#endif