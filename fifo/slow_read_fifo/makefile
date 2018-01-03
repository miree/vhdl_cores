# generic rules
%.o: %.vhdl
	ghdl -a  $<
%.o: %.vhd
	ghdl -a  $<



# main target is the wave output file
all: simulation.ghw

# view target generates the wave file and starts the viewer
view: simulation.ghw 
	gtkwave simulation.ghw --save=simulation.gtkw &

simulation.ghw: testbench makefile
	ghdl -r testbench --stop-time=1000000ns --wave=simulation.ghw
	gconftool-2 --type string --set /com.geda.gtkwave/0/reload 0

# additional dependencies for testbench.o (it depends on the packages that it uses)
# testbench needs to be re-analyzed whenever fifo_pkg changed
testbench.o:           \
	fifo_pkg.o         \
	guarded_fifo_pkg.o \
	
# module "$(COMPONENT).o" must be before the testbench "$(COMPONENT)_tb.o" in the dependency list
testbench:  fifo.o fifo_pkg.o \
			guarded_fifo.o guarded_fifo_pkg.o \
			testbench.o 
	ghdl -e  testbench

clean:
	rm *.o testbench work-obj93.cf simulation.ghw
