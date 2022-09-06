library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbp_pkg.all;

entity testbench is
end entity;

architecture simulation of testbench is
	constant c_clk_freq : integer := 12000000; -- 12 MHz clock 
	constant c_clk_period : time := 1000000000 ns/c_clk_freq;  
	constant c_baud_rate: integer := 6000000; -- choose relatively high baud rate for a reasonably fast simulation
	signal clk    : std_logic := '1';
	signal rst    : std_logic := '1';

	-- parallel data
	signal dat    : std_logic_vector(7 downto 0) := (others => '0');
	signal stb    : std_logic := '0';

	-- serial data
	signal chip_tx_to_fpga_rx : std_logic := '1';
	signal fpga_tx_to_chip_rx : std_logic := '1';

	-- wishbone
	signal wbp : t_wbp := c_wbp_init;
	signal fpga : t_wbp := c_wbp_init;
	signal to_host : t_wbp := c_wbp_init;

	type t_state is (s_idle, s_wait_for_ack);
	signal state : t_state := s_idle;

	signal reg  : std_logic_vector(31 downto 0) := (others => '0');	
begin

	clk <= not clk after c_clk_period/2;
	rst <=     '0' after c_clk_period*5;

	uart_chip: entity work.uart_chipsim
	generic map(
		g_baud_rate => c_baud_rate
	)
	port map (
		tx_o => chip_tx_to_fpga_rx,
		rx_i => fpga_tx_to_chip_rx
	);

	master: entity work.uart_wbp
	generic map (
		g_clk_freq  => c_clk_freq,
		g_baud_rate => c_baud_rate
	)
	port map (
		clk_i    => clk,
		rst_i    => rst,

		-- serial lines 
		rx_i     => chip_tx_to_fpga_rx,
		tx_o     => fpga_tx_to_chip_rx,

		-- wishbone master
		master_o => wbp.mosi,
		master_i => wbp.miso,

		-- loopback to slave interface
		slave_i  => wbp.mosi,
		slave_o  => wbp.miso

		-- open slave interface
		-- slave_i  => c_wbp_slave_in_init,--wbp.mosi,
		-- slave_o  => open--wbp.miso
	);

	-- in case of an open slave interface, this 
	-- deadbeef acknowledgement can be connected to the master interface
	--wbp.miso.stall <= '1';
	--wbp.miso.ack <= wbp.mosi.stb;
	--wbp.miso.dat <= x"deadbeef";

	--mux: entity work.wbp_2s1m
	--port map(
	--	clk_i    => clk,
	--	slaves_i(0) => wbp.mosi,
	--	slaves_i(1) => fpga.mosi,
	--	slaves_o(0) => wbp.miso,
	--	slaves_o(1) => fpga.miso,
	--	master_o => to_host.mosi,
	--	master_i => to_host.miso
	--	);

	--wb_master: process

	--begin
	--	wait until rising_edge(clk);

	--	case state is
	--		when s_idle =>

	--			if wbp.mosi.cyc = '0' then 
	--				fpga.mosi.cyc <= '1';
	--				fpga.mosi.stb <= '1';
	--				fpga.mosi.adr <= x"00001234";
	--				fpga.mosi.dat <= x"0000affe";
	--				fpga.mosi.we  <= '1';
	--				fpga.mosi.sel <= "1111";
	--				state <= s_wait_for_ack;
	--				if fpga.miso.stall = '0' then
	--					state <= s_wait_for_ack;	
	--				end if;
	--			end if;

	--		when s_wait_for_ack =>
	--			if fpga.miso.ack = '1' or fpga.miso.err = '1' or fpga.miso.rty = '1' then
	--				state <= s_idle;
	--				fpga.mosi.cyc <= '0';
	--				fpga.mosi.stb <= '0';
	--			end if;

	--	end case;

	--end process;

end architecture;