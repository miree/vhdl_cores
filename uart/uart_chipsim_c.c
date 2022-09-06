#define _GNU_SOURCE 
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <errno.h>
#include <string.h>
#include <termios.h>
#include <stdlib.h>
#include <poll.h>


#define VARNAME work__uart_chipsim__my_var
#define TIMEOUT -1
#define HANGUP  -2

struct pollfd pfds[1] = {0,};
unsigned char write_buffer[32768] = {0,};
int write_buffer_length = 0;


void uart_chipsim_init(int stop_until_connected) {
	if (stop_until_connected && pfds[0].fd != 0) {
		close(pfds[0].fd);
		pfds[0].fd = 0;
	}
	if (pfds[0].fd == 0) {
		int fd = open("/dev/ptmx", O_RDWR | O_NONBLOCK);


	    struct termios raw;
		if (tcgetattr(fd, &raw) == 0)
		{
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
			raw.c_cc[VMIN] = 0; raw.c_cc[VTIME] = 0; // immediate - anything      

			// put terminal in raw mode after flushing 
			if (tcsetattr(fd,TCSAFLUSH,&raw) < 0) 
			{
				int err = errno;
				printf("Error, cant set raw mode: %s\n", strerror(err));
				return;
			}
		}


		// print the name of the pseudo terminal in device tree
		char name[256];
		ptsname_r(fd, name, 256);
		printf("serial-device : %s  ",name);
		printf("(can be obtained using: cat /tmp/uart_chipsim_device)\n");
		// write the device name into a file
		FILE *f = fopen("/tmp/uart_chipsim_device","w+");
		fprintf(f,"%s\n",name);
		fclose(f);
		if (stop_until_connected) {
			printf("waiting for client, simulation stopped ...");
		} else {
			printf("device is ready, simulation is running\n");
		}
		fflush(stdout);
		grantpt(fd);
		unlockpt(fd);
		pfds[0].fd = fd;
	}
	if (stop_until_connected)
	{
		pfds[0].events = POLLIN;
		poll(pfds,1,-1);
		printf(" connected, simulation continues\n");
	}
}

int uart_chipsim_read(int timeout_value) {
	//printf("uart_chipsim_read ");
	unsigned char ch = 0;
	pfds[0].events = POLLIN | POLLHUP;
	if (poll(pfds,1,timeout_value) == 0) {
		//printf("timeout\n");
		return TIMEOUT;
	}
	if (pfds[0].revents == POLLHUP) { // client disconnected
		//printf("hangup\n");
		return HANGUP;  
	}
	ssize_t result = read(pfds[0].fd, &ch, 1);
	if (result == 1) { // successful read
		printf("<< 0x%02x\n", (int)ch);
		return ch;
	} else if (result == -1) { // error
		printf("error while read %d %s\n", errno, strerror(errno));
	}
	return TIMEOUT;
}

void uart_chipsim_write(int x) {
	//printf("uart_chipsim_write");
	unsigned char ch = x;
	write_buffer[write_buffer_length++] = ch;
	printf("  >> 0x%02x\n", (int)x);
}

void uart_chipsim_flush() {
	pfds[0].events = POLLOUT;
	poll(pfds,1,-1);
	int result = write(pfds[0].fd, write_buffer, write_buffer_length);
	write_buffer_length = 0;
	if (result == -1) {
		printf("error while write %d %s\n", errno, strerror(errno));
	}
	// printf("all written %d\n", result);
}

