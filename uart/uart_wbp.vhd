library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;
use work.wbp_pkg.all;
use work.uart_pkg.all;

entity uart_wbp is 
generic (
	g_clk_freq  : integer := 12000000;
	g_baud_rate : integer := 9600);
port (
	clk_i :  in std_logic;
	rst_i :  in std_logic;
	-- serial 
	rx_i  :  in std_logic;
	tx_o  : out std_logic;
	-- wishbone master
	master_o : out t_wbp_master_out;
	master_i :  in t_wbp_master_in;
	-- wishbone slave (for MSIs to host)
	slave_i  :  in t_wbp_slave_in;
	slave_o  : out t_wbp_slave_out;
  -- general purpose output bits
 	gpo_bits_o  : out std_logic_vector(31 downto 0)
);
end entity;

architecture rtl of uart_wbp is
	signal rx_parallel : t_uart_parallel := c_uart_parallel_init;
	signal tx_parallel : t_uart_parallel := c_uart_parallel_init;
	signal tx_parallel_from_slave  : t_uart_parallel := c_uart_parallel_init;
	signal tx_parallel_from_slave_registered  : t_uart_parallel := c_uart_parallel_init;
	signal tx_parallel_from_master : t_uart_parallel := c_uart_parallel_init;
	signal wbta_req    : t_wbta_request  := c_wbta_request_init;
	signal wbta_rsp    : t_wbta_response := c_wbta_response_init;
	signal wbta_config : t_configuration := c_configuration_init;
	signal wbta_stb_resp: t_wbp_response := c_wbp_response_init; 

	signal rst : std_logic := '0';
	signal bridge_reset : std_logic := '0';
begin

	rst <= rst_i or bridge_reset;
	
	rx: entity work.uart_rx_buffer
	generic map (
		g_clk_freq  => g_clk_freq,
		g_baud_rate => g_baud_rate,
		g_bits      => 8
	)
	port map (
		clk_i   => clk_i,
		-- uart serial interface
		rx_i    => rx_i,
		-- parallel interface
		dat_o   => rx_parallel.dat,
		stb_o   => rx_parallel.stb,
		stall_i => rx_parallel.stall
	);

	tx: entity work.uart_tx
	generic map (
		g_clk_freq  => g_clk_freq,
		g_baud_rate => g_baud_rate,
		g_bits      => 8
	)
	port map (
		clk_i   => clk_i,
		-- uart serial interface
		tx_o    => tx_o,
		-- parallel interface
		dat_i   => tx_parallel.dat,
		stb_i   => tx_parallel.stb,
		stall_o => tx_parallel.stall
	);

	tx_multiplixer: entity work.uart_multiplex
	generic map (
		g_bits      => 8
	)
	port map (
		clk_i    => clk_i,
		-- parallel out 
		dat_o   => tx_parallel.dat,
		stb_o   => tx_parallel.stb,
		stall_i => tx_parallel.stall,
		-- parallel in 1
		dat_1_i   => tx_parallel_from_master.dat,
		stb_1_i   => tx_parallel_from_master.stb,
		stall_1_o => tx_parallel_from_master.stall,
		-- parallel in 2
		dat_2_i   => tx_parallel_from_slave.dat,
		stb_2_i   => tx_parallel_from_slave.stb,
		stall_2_o => tx_parallel_from_slave.stall
	);

	--tx_uart_register: entity work.uart_register
	--generic map (
	--	g_bits      => 8
	--)
	--port map (
	--	clk_i    => clk_i,
	--	-- parallel out 
	--	dat_o   => tx_parallel_from_slave_registered.dat,
	--	stb_o   => tx_parallel_from_slave_registered.stb,
	--	stall_i => tx_parallel_from_slave_registered.stall,
	--	-- parallel in 1
	--	dat_i   => tx_parallel_from_slave.dat,
	--	stb_i   => tx_parallel_from_slave.stb,
	--	stall_o => tx_parallel_from_slave.stall
	--);

	uart_rx_to_wbta_req: entity work.uart_wbta
	port map (
		clk_i    => clk_i,
		rst_i    => rst,
		-- uart receiver interface
		rx_dat_i   => rx_parallel.dat,
		rx_stb_i   => rx_parallel.stb,
		rx_stall_o => rx_parallel.stall,
		-- wishbone transaction request interface
		wbta_dat_o   => wbta_req.dat,
    	wbta_stb_o   => wbta_req.stb,
    	wbta_stall_i => wbta_req.stall,
    	-- configuration
    	config_o     => wbta_config,
    	-- host response
    	stb_resp_o   => wbta_stb_resp,
    	-- general purpose output bits
    	gpo_bits_o   => gpo_bits_o,
    	-- bridge reset initiated by host
    	bridge_reset_o => bridge_reset
	);

	wbta_rsp_to_uart_tx: entity work.wbta_uart
	port map (
		clk_i  => clk_i,
		rst_i  => rst,
		-- parallel inteface
		tx_dat_o   => tx_parallel_from_master.dat,
		tx_stb_o   => tx_parallel_from_master.stb,
		tx_stall_i => tx_parallel_from_master.stall,
		-- wishbone transaction response interface
		wbta_dat_i   => wbta_rsp.dat,
		wbta_stb_i   => wbta_rsp.stb,
		wbta_stall_o => wbta_rsp.stall
	);

	master: entity work.wbta_wbp_master
	port map(
		clk_i   => clk_i,
		rst_i   => rst, 
		-- this interface takes a strobe request
		tract_i => wbta_req.dat,
		stb_i   => wbta_req.stb,
		stall_o => wbta_req.stall,
		-- this interface delivers the strobe response
		tract_o => wbta_rsp.dat,
		stb_o   => wbta_rsp.stb,
		stall_i => wbta_rsp.stall,
		-- configuration of write behavior
		config_write_response_i => wbta_config.fpga_sends_write_response,
		-- a normal wishbone master
		wb_cyc_o    => master_o.cyc,
		wb_stb_o    => master_o.stb,
		wb_we_o     => master_o.we,
		wb_adr_o    => master_o.adr,
		wb_dat_o    => master_o.dat,
		wb_sel_o    => master_o.sel,
		wb_stall_i  => master_i.stall,
		wb_ack_i    => master_i.ack,
		wb_err_i    => master_i.err,
		wb_rty_i    => master_i.rty,
		wb_dat_i    => master_i.dat
	);

	slave: entity work.wb_uart
	port map (
		clk_i    => clk_i,
		rst_i    => rst_i,
		-- bridge reset from host
    	bridge_reset_i => bridge_reset,
    	-- configuration
    	config_write_response_i => wbta_config.host_sends_write_response,
    	-- host response
    	stb_resp_i   => wbta_stb_resp,
		-- uart transmitter interface
		tx_dat_o   => tx_parallel_from_slave.dat,
		tx_stb_o   => tx_parallel_from_slave.stb,
		tx_stall_i => tx_parallel_from_slave.stall,
		-- wishbone slave interface
		dat_i    => slave_i.dat,
		adr_i    => slave_i.adr,
		sel_i    => slave_i.sel,
		cyc_i    => slave_i.cyc,
		stb_i    => slave_i.stb,
		we_i     => slave_i.we,
		stall_o  => slave_o.stall,
		ack_o    => slave_o.ack,
		rty_o    => slave_o.rty,
		err_o    => slave_o.err,
		dat_o    => slave_o.dat
	);


end architecture;