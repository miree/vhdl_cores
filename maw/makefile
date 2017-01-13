
%.o: %.vhd
	ghdl -a --ieee=synopsys $<

%.o: %.vhdl
	ghdl -a --ieee=synopsys $<

all: maw_tb.ghw

view: maw_tb.ghw
	gtkwave maw_tb.ghw --save=maw_tb_view.gtkw &

maw_tb.ghw: maw_tb makefile
	./maw_tb --stop-time=150000ns --wave=maw_tb.ghw
	gconftool-2 --type string --set /com.geda.gtkwave/0/reload 0

maw_tb.o: delay.o delay_pkg.o \
		  maw.o maw_pkg.o 

maw_tb: delay.o delay_pkg.o \
	    maw.o maw_pkg.o     \
	    maw_tb.o
	ghdl -e --ieee=synopsys maw_tb

clean:
	rm *.o maw_tb maw_tb.ghw work-obj93.cf
