GHDLFLAGS = --ieee=synopsys --std=93c \
	-fexplicit -frelaxed-rules --no-vital-checks --warn-binding --mb-comments

# main target is the wave output file
all: simulation.ghw

# view target generates the wave file and starts the viewer
view: simulation.ghw 
	gtkwave simulation.ghw --save=simulation.gtkw &

notrace:
	ghdl -r testbench --ieee-asserts=disable

run: uart_wbp
	ghdl -r testbench --stop-time=1000us --wave=simulation.ghw --ieee-asserts=disable  &
	sleep 1
	./uart_wbp $(shell cat /tmp/uart_chipsim_device) -v 0x10000000 0xaffe -g 0x12345678        # write access
	./uart_wbp $(shell cat /tmp/uart_chipsim_device) -v 0x10000000        -w 1000 # read access

run-test: uart_wbp_automatic_test
	ghdl -r testbench --ieee-asserts=disable  &
	sleep 1
	./uart_wbp_automatic_test $(shell cat /tmp/uart_chipsim_device)
	killall testbench

uart_wbp: ../uart_wbp.c ../uart_wbp_access.c
	gcc -Wall -o $@ $+

uart_wbp_automatic_test: ../uart_wbp_automatic_test.c ../uart_wbp_access.c
	gcc -Wall -o $@ $+

# start simulation (which regenerates wave file), then update viewer
simulation.ghw: testbench run

testbench: 	uart_chipsim_c.o                    \
			../../wishbone/wbp_pkg.vhd          \
			../../wishbone/wbp_mux.vhd          \
			../../wishbone/wbta_pkg.vhd         \
			../../wishbone/wbta_wbp_master.vhd  \
			../uart.vhd                         \
			../uart_wbp_components.vhd          \
			../uart_wbp.vhd                     \
			../uart_chipsim.vhd                 \
			testbench.vhd
	ghdl -a $(GHDLFLAGS) $(filter-out uart_chipsim_c.o, $+)
	ghdl -m -Wl,uart_chipsim_c.o \
	        $(GHDLFLAGS) testbench 

uart_chipsim_c.o: ../uart_chipsim_c.c
	gcc -Wall -c $<

clean:
	rm -f *.o testbench uart_wbp work-obj*.cf simulation.ghw 
