

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;

-- a module that handles one pipelined wishbone strobe
-- it takes strobe requests an delivers the response
entity wbta_wbp_master is
port (
	clk_i   :  in std_logic;
	rst_i   :  in std_logic;

	-- this interface takes a strobe request
	tract_i :  in t_wbp_transaction_request;
	stb_i   :  in std_logic;
	stall_o : out std_logic;

	-- this interface delivers the strobe response
	tract_o : out t_wbp_transaction_response;
	stb_o   : out std_logic;
	stall_i :  in std_logic;

	-- configuration if a response to write strobes is expected
	config_write_response_i :  in std_logic;

	-- a normal wishbone master
	wb_cyc_o    : out std_logic;
	wb_stb_o    : out std_logic;
	wb_we_o     : out std_logic;
	wb_adr_o    : out std_logic_vector(31 downto 0);
	wb_dat_o    : out std_logic_vector(31 downto 0);
	wb_sel_o    : out std_logic_vector( 3 downto 0);
	wb_stall_i  :  in std_logic;
	wb_ack_i    :  in std_logic;
	wb_err_i    :  in std_logic;
	wb_rty_i    :  in std_logic;
	wb_dat_i    :  in std_logic_vector(31 downto 0));
end entity;

architecture rtl of wbta_wbp_master is
	signal stall_out  : std_logic := '0';
	signal tract_out  : t_wbp_transaction_response := c_wbp_transaction_response_init;
	signal stb_out    : std_logic := '0';
	signal stall_timeout_count : unsigned(31 downto 0) := (others => '0');
	signal stall_timeout_active: boolean := false;
	
	signal wb_cyc_out    : std_logic := '0';
	signal wb_stb_out    : std_logic := '0';
	signal wb_we_out     : std_logic := '0';
	signal wb_adr_out    : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_dat_out    : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_sel_out    : std_logic_vector( 3 downto 0) := (others => '0');

	signal keep_cycle : std_logic := '0';

	type t_state is (s_idle, s_wait_for_ack, s_send_response);
	signal state : t_state := s_idle;
begin
	stall_o  <= stall_out;
	tract_o <= tract_out;
	stb_o    <= stb_out;
	
	wb_cyc_o   <= wb_cyc_out;
	wb_stb_o   <= wb_stb_out;
	wb_we_o    <= wb_we_out;
	wb_adr_o   <= wb_adr_out;
	wb_dat_o   <= wb_dat_out;
	wb_sel_o   <= wb_sel_out;

	stall_out <= '0' when state = s_idle else '1';

	process
	begin 
		wait until rising_edge(clk_i);

		if rst_i = '1' then
			tract_out            <= c_wbp_transaction_response_init;
			stb_out              <= '0';
			stall_timeout_count  <= (others => '0');
			stall_timeout_active <= false;
			wb_cyc_out           <= '0';
			wb_stb_out           <= '0';
			wb_we_out            <= '0';
			wb_adr_out           <= (others => '0');
			wb_dat_out           <= (others => '0');
			wb_sel_out           <= (others => '0');
			state <= s_idle;
			keep_cycle <= '0';

		else

			case state is
				when s_idle =>
					if stb_i = '1' then
						stall_timeout_active <= tract_i.stall_timeout /= 0;	
						stall_timeout_count  <= tract_i.stall_timeout;
						wb_cyc_out <= '1';
						wb_stb_out <= '1';
						wb_adr_out <= tract_i.adr;
						wb_dat_out <= tract_i.dat;
						wb_sel_out <= tract_i.sel;
						tract_out.sel  <= tract_i.sel;
						wb_we_out  <= tract_i.we;
						tract_out.we   <= tract_i.we;
						keep_cycle     <= tract_i.cyc; 
						state <= s_wait_for_ack;
					end if; 
				when s_wait_for_ack =>
					if wb_stall_i = '0' then
						wb_stb_out <= '0'; 
					elsif stall_timeout_active then 
						stall_timeout_count <= stall_timeout_count - 1;
					end if;
					tract_out.dat <= wb_dat_i;
					tract_out.ack <= wb_ack_i;
					tract_out.err <= wb_err_i;
					tract_out.rty <= wb_rty_i;
					tract_out.stall_timeout <= stall_timeout_count(31);
					if wb_ack_i = '1' or wb_err_i = '1' or wb_rty_i = '1' or 
						 (stall_timeout_active and stall_timeout_count(31) = '1') then
						if keep_cycle = '0' then
							wb_cyc_out <= '0'; 
						end if;
						if config_write_response_i = '1' or wb_we_out = '0' then
							stb_out <= '1';
							state   <= s_send_response;
						else 
							state <= s_idle;
						end if;
					end if; 
				when s_send_response =>
					if stall_i = '0' then
						stb_out <= '0';
						state   <= s_idle;
					end if;
			end case;

		end if;

	end process;

end architecture;
