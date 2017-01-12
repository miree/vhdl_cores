
%.o: %.vhd
	ghdl -a --ieee=synopsys $<

%.o: %.vhdl
	ghdl -a --ieee=synopsys $<

all: delay_tb.ghw

view: delay_tb.ghw
	gtkwave delay_tb.ghw --save=delay_tb_view.gtkw &

delay_tb.ghw: delay_tb makefile
	./delay_tb --stop-time=150000ns --wave=delay_tb.ghw
	gconftool-2 --type string --set /com.geda.gtkwave/0/reload 0

delay_tb.o: delay.o delay_pkg.o

delay_tb: delay.o delay_pkg.o delay_tb.o
	ghdl -e --ieee=synopsys delay_tb

clean:
	rm *.o delay_tb delay_tb.ghw work-obj93.cf
