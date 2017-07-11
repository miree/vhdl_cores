
%.o: %.vhd
	ghdl -a --ieee=synopsys $<

%.o: %.vhdl
	ghdl -a --ieee=synopsys $<

all: delayline_tb.ghw

view: delayline_tb.ghw
	gtkwave delayline_tb.ghw --save=delayline_tb_view.gtkw &

delayline_tb.ghw: delayline_tb makefile
	./delayline_tb --stop-time=150000ns --wave=delayline_tb.ghw
	gconftool-2 --type string --set /com.geda.gtkwave/0/reload 0

delayline_tb.o: fifo.o       \
				serializer.o \
	            delayline.o  

delayline_tb: fifo.o         \
			  serializer.o   \
	          delayline.o    \
	          delayline_tb.o 
	ghdl -e --ieee=synopsys delayline_tb

clean:
	rm *.o delayline_tb delayline_tb.ghw work-obj93.cf
