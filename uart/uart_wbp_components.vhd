-- Components that can be used to build a bidirectional 
-- UART-wishbone bridge between FPGA and host system


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;

-- Transfrom incoming bytes into wishbone transactions
--  This is a very simple implementation
entity simple_uart_wbta is 
port (
	clk_i    :  in std_logic;
	rst_i    :  in std_logic;
	-- uart receiver interface
	rx_dat_i   :  in std_logic_vector(7 downto 0);
	rx_stb_i   :  in std_logic;
	rx_stall_o : out std_logic;
	-- uart transmitter interface
	tx_dat_o   : out std_logic_vector(7 downto 0);
	tx_stb_o   : out std_logic;
	tx_stall_i :  in std_logic;
	-- wishbone transaction interface
	wbta_dat_o   : out t_wbp_transaction_request;
	wbta_stb_o   : out std_logic;
	wbta_stall_i :  in std_logic;
	-- wishbone transaction response
	wbta_rsp_i  :  in t_wbp_transaction_response;
	wbta_stb_i   :  in std_logic;
	wbta_stall_o : out std_logic;
	-- soft reset command can be triggered by serial command "11111111"
	bridge_reset_o : out std_logic
);
end entity;

architecture rtl of simple_uart_wbta is
	type t_state is (s_idle, s_receive_low, s_receive_high, s_wbta_stb, s_transmit_rsp_header, s_transmit_high, s_transmit_low);
	signal state : t_state := s_idle;

	signal tx_dat_out   :  std_logic_vector(7 downto 0) := (others => '0');
	signal tx_stb_out   :  std_logic := '0';

	signal wb_dat : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_adr : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_sel : std_logic_vector( 3 downto 0) := (others => '1');

	signal wbta_we_out  : std_logic := '0';
	signal wbta_stb_out : std_logic := '0';

	signal we : std_logic := '0';
	signal adr4 : std_logic_vector(6 downto 0) := (others => '0'); -- this can only reach 128 different wb addresses

	signal bridge_reset_out : std_logic := '0';
begin 

	tx_dat_o <= tx_dat_out;
	tx_stb_o <= tx_stb_out;

	-- we can only take rx_data in s_idle or s_receive state
	rx_stall_o <= '0' when state = s_idle or state = s_receive_low or state = s_receive_high
					 else '1';

	wbta_stall_o <= '0' when state = s_idle and wbta_stb_i = '1' and rx_stb_i = '0'
					else '1';

	bridge_reset_o <= bridge_reset_out;					 

	-- wishbone transaction output signals
	wbta_dat_o.adr <= wb_adr;
	wbta_dat_o.sel <= wb_sel;
	wbta_dat_o.dat <= wb_dat;
	wbta_dat_o.cyc <= '0'; -- this is the bit that controls cyc after stb response (ack,err,rty, or timeout)
	wbta_dat_o.we  <= wbta_we_out;
	wbta_dat_o.stall_timeout <= (others => '0');
	wbta_stb_o <= wbta_stb_out;

	we <= rx_dat_i(7);
	adr4 <= rx_dat_i(6 downto 0);

	process 
	begin
		wait until rising_edge(clk_i);
		bridge_reset_out <= '0';
		case state is
			when s_idle =>
				if rx_stb_i = '1' then
					if rx_dat_i = "11111111" then
						bridge_reset_out <= '1';
					else
						wb_adr(8 downto 0) <= adr4 & "00";
						wbta_we_out <= we;
						if we = '1' then 
							state <= s_receive_low;
						else
							wbta_stb_out <= '1';
							state <= s_wbta_stb;
						end if;
					end if;
				elsif wbta_stb_i = '1' then
					wb_dat(15 downto 0) <= wbta_rsp_i.dat(15 downto 0);
					tx_stb_out <= '1';
					tx_dat_out <= x"80"; -- send the read-response-header
					state <= s_transmit_rsp_header;
				end if;
			when s_receive_low =>
				if rx_stb_i = '1' then
					wb_dat(7 downto 0) <= rx_dat_i;
					state <= s_receive_high;
				end if;
			when s_receive_high =>
				if rx_stb_i = '1' then
					wb_dat(15 downto 8) <= rx_dat_i;
					state <= s_wbta_stb;
					wbta_stb_out <= '1';
				end if;
			when s_wbta_stb =>
				if wbta_stall_i = '0' then
					wbta_stb_out <= '0';
					state <= s_idle;
				end if;

			when s_transmit_rsp_header =>
				if tx_stall_i = '0' then 
					tx_dat_out <= wb_dat(15 downto 8);
					state      <= s_transmit_high;
				end if;
			when s_transmit_high =>
				if tx_stall_i = '0' then 
					tx_dat_out <= wb_dat(7 downto 0);
					state      <= s_transmit_low;
				end if;
			when s_transmit_low =>
				if tx_stall_i = '0' then 
					tx_stb_out <= '0';
					state <= s_idle;
				end if;

		end case;
	end process;

end architecture;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;

entity wb_simple_uart is 
port (
	clk_i    :  in std_logic;
	rst_i    :  in std_logic;
	-- uart transmitter interface
	tx_dat_o   : out std_logic_vector(7 downto 0);
	tx_stb_o   : out std_logic;
	tx_stall_i :  in std_logic;
	-- wishbone slave interface
	dat_i    :  in std_logic_vector(31 downto 0);
	adr_i    :  in std_logic_vector(31 downto 0);
	sel_i    :  in std_logic_vector( 3 downto 0);
	cyc_i    :  in std_logic;
	stb_i    :  in std_logic;
	we_i     :  in std_logic;
	stall_o  : out std_logic;
	ack_o    : out std_logic;
	rty_o    : out std_logic;
	err_o    : out std_logic;
	dat_o    : out std_logic_vector(31 downto 0)
);
end entity;

architecture rtl of wb_simple_uart is
	
	signal tx_dat_out : std_logic_vector(7 downto 0) := (others => '0');
	signal tx_stb_out : std_logic := '0';
	signal ack_out    : std_logic := '0';
	signal rty_out    : std_logic := '0';
	signal err_out    : std_logic := '0';
	signal dat_out    : std_logic_vector(31 downto 0) := (others => '0');

	signal wb_dat : std_logic_vector(15 downto 0) := (others => '0');
	signal wb_adr : std_logic_vector( 6 downto 0) := (others => '0');


	type t_state is  (s_idle, 
					  s_transmit_header,
					  s_transmit_high,
					  s_transmit_low);

	signal state : t_state := s_idle;

begin 

	tx_dat_o <= tx_dat_out;
	tx_stb_o <= tx_stb_out;

	stall_o  <= '0' when state = s_idle else '1';
	ack_o    <= ack_out;
	rty_o    <= rty_out;
	err_o    <= err_out;
	dat_o    <= dat_out;

	process 
	begin
		wait until rising_edge(clk_i);
		ack_out <= '0'; 
		rty_out <= '0'; 
		err_out <= '0'; 
		dat_out <= (others => '0'); 

		if rst_i = '1' then
			state <= s_idle;
		else
			case state is 
				when s_idle =>
					if cyc_i = '1' and stb_i = '1' then
						if we_i = '1' then 
							ack_out <= '1';
							wb_dat <= dat_i(15 downto 0);
							tx_dat_out <= '0' & adr_i(8 downto 2);
							tx_stb_out <= '1';
							state <= s_transmit_header;
						else 
							err_out <= '1';
						end if;
					end if;
				when s_transmit_header =>
					if tx_stall_i = '0' then
						tx_dat_out <= wb_dat(15 downto 8);
						state <= s_transmit_high;
					end if;
				when s_transmit_high =>
					if tx_stall_i = '0' then
						tx_dat_out <= wb_dat(7 downto 0);
						state <= s_transmit_low;
					end if;
				when s_transmit_low =>
					if tx_stall_i = '0' then
						tx_dat_out <= wb_dat(7 downto 0);
						tx_stb_out <= '0';
						state <= s_idle;
					end if;
			end case;
		end if;
	end process;

end architecture;










library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;

-- Transfrom incoming bytes into wishbone transactions
-- Internal state: registers for adr,dat,sel and
--   the state of the state-machine
entity uart_wbta is 
port (
	clk_i    :  in std_logic;
	rst_i    :  in std_logic;
	-- uart receiver interface
	rx_dat_i   :  in std_logic_vector(7 downto 0);
	rx_stb_i   :  in std_logic;
	rx_stall_o : out std_logic;
	-- wishbone transaction interface
	wbta_dat_o   : out t_wbp_transaction_request;
	wbta_stb_o   : out std_logic;
	wbta_stall_i :  in std_logic;
	-- response interface from host to wishbone slave interface (wb_uart)
	config_o    : out t_configuration;
	stb_resp_o  : out t_wbp_response;
	-- general purpose output bits
	gpo_bits_o  : out std_logic_vector(31 downto 0);
	-- this reset can be initiated by the host
	bridge_reset_o : out std_logic
);
end entity;

architecture rtl of uart_wbta is
	signal wb_dat : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_adr : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_sel : std_logic_vector( 3 downto 0) := (others => '0');
	signal stall_timeout : std_logic_vector(31 downto 0) := (others => '0');
	signal gpo_bits : std_logic_vector(31 downto 0) := (others => '0');
	type t_state is (s_idle, s_receive, s_stb);
	signal state : t_state := s_idle;


	type t_command is (command_config,    -- command code 0
									 command_set_sel,     -- command code 1
									 command_set_dat,     -- command code 2
									 command_set_adr,     -- command code 3
									 command_write_stb,   -- command code 4
									 command_read_stb,    -- command code 5
									 command_set_timeout, -- command code 6
									 command_slave_ack,   -- command code 7
									 command_slave_err,   -- command code 8 
									 command_slave_rty,   -- command code 9
									 command_set_gpo,     -- command code 10
									 command_reset,       -- command code 11
									 command_invalid);   

	-- type conversion function to t_command
	function to_t_command (encoding : std_logic_vector) return t_command is 
	begin
		for cmd in t_command'left to t_command'right loop 
			if to_integer(unsigned(encoding)) = t_command'pos(cmd) then
				return cmd;
			end if;
		end loop;
		return command_invalid;
	end function;

	signal command   : t_command := command_invalid;
	signal mask      : std_logic_vector(3 downto 0) := (others => '0');

	procedure start_receive(signal init_mask : in std_logic_vector(3 downto 0); signal byte : out t_byte_select; signal new_state : out t_state) is
	begin
		if init_mask /= "0000" then 
			byte      <= init_byte_select(init_mask);
			new_state <= s_receive;
		end if;
	end procedure;

	signal byte_select : t_byte_select := c_byte_select_zero;

	signal wbta_we_out  : std_logic := '0';
	signal wbta_stb_out : std_logic := '0';

	type t_receive_type is (receive_adr, receive_dat, receive_timeout, receive_gpo_bits);
	signal receive_type : t_receive_type;

	signal delta_adr : signed(2 downto 0) := (others => '0'); -- this changes the address after stb to optimize successive strobes with increasing address

	signal config_out : t_configuration := c_configuration_init;
	signal stb_resp_out : t_wbp_response := c_wbp_response_init;

	signal gpo_bits_out : std_logic_vector(31 downto 0) := (others => '0');

	signal bridge_reset_out : std_logic := '0';
	signal reset_just_happened : std_logic := '0';

begin

	-- we can only take rx_data in s_idle or s_receive state
	rx_stall_o <= '0' when state = s_idle or state = s_receive 
					 else '1';

	-- wishbone transaction output signals
	wbta_dat_o.adr <= wb_adr;
	wbta_dat_o.sel <= wb_sel;
	wbta_dat_o.dat <= wb_dat;
	wbta_dat_o.cyc <= mask(3); -- this is the bit that controls cyc after stb response (ack,err,rty, or timeout)
	wbta_dat_o.we  <= wbta_we_out;
	wbta_dat_o.stall_timeout <= unsigned(stall_timeout);
	wbta_stb_o <= wbta_stb_out;

	config_o <= config_out;  
	stb_resp_o <= stb_resp_out;

	gpo_bits_o <= gpo_bits_out;

	bridge_reset_o <= bridge_reset_out;

	-- the incoming byte consists of a 
	-- 4-bit mask in the most significant half 
	-- and a 4-bit command in the least significant half.
	mask     <=              rx_dat_i(7 downto 4);
	command  <= to_t_command(rx_dat_i(3 downto 0)) when rx_stb_i = '1' and state = s_idle 
			 else command_invalid; 

	process
	begin
		wait until rising_edge(clk_i);

		if rst_i = '1' then 
			reset_just_happened <= '1';
		end if;

		stb_resp_out <= c_wbp_response_init;
		bridge_reset_out <= '0';

		case state is

			when s_idle =>
				gpo_bits_out <= gpo_bits;

				if rx_stb_i = '1' then
					case command is
						when command_config =>
							reset_just_happened <= '0';
							config_out.host_sends_write_response <= mask(0);
							config_out.fpga_sends_write_response <= mask(1);
						when command_set_sel => 
							reset_just_happened <= '0';
							wb_sel <= mask;
						when command_set_dat => 
							reset_just_happened <= '0';
							receive_type <= receive_dat;
								start_receive(mask, byte_select, state);
						when command_set_adr => 
							reset_just_happened <= '0';
							receive_type <= receive_adr;
								start_receive(mask, byte_select, state);
						when command_set_timeout => 
							reset_just_happened <= '0';
							receive_type <= receive_timeout;
								start_receive(mask, byte_select, state);
						when command_write_stb => 
							reset_just_happened <= '0';
								wbta_stb_out <= '1';
								wbta_we_out  <= '1';
								delta_adr <= signed(mask(2 downto 0));
							state <= s_stb;
						when command_read_stb => 
							reset_just_happened <= '0';
								wbta_stb_out <= '1';
								wbta_we_out  <= '0';
								delta_adr <= signed(mask(2 downto 0));
							state <= s_stb;
						when command_slave_ack => 
							reset_just_happened <= '0';
							stb_resp_out.ack <= '1';
							stb_resp_out.dat <= wb_dat;
						when command_slave_err => 
							reset_just_happened <= '0';
							stb_resp_out.err <= '1';
							stb_resp_out.dat <= wb_dat;
						when command_slave_rty => 
							reset_just_happened <= '0';
							stb_resp_out.rty <= '1';
							stb_resp_out.dat <= wb_dat;
						when command_set_gpo => 
							reset_just_happened <= '0';
							receive_type <= receive_gpo_bits;
								start_receive(mask, byte_select, state);
						when command_reset =>
							reset_just_happened <= '1';
							if reset_just_happened = '0' then
								bridge_reset_out <= '1';
								wb_dat           <= (others => '0');
								wb_adr           <= (others => '0');
								wb_sel           <= (others => '0');
								stall_timeout    <= (others => '0');
								gpo_bits         <= (others => '0');
								state            <= s_idle;
							end if;

						when others => 
					end case;
				end if;

			when s_receive =>

				if rx_stb_i = '1' then
					if receive_type = receive_dat then -- distinguish between data and address settings
						wb_dat((byte_select.idx+1)*8-1 downto byte_select.idx*8) <= rx_dat_i;
					elsif receive_type = receive_adr then
						wb_adr((byte_select.idx+1)*8-1 downto byte_select.idx*8) <= rx_dat_i;
					elsif receive_type = receive_timeout then
						stall_timeout((byte_select.idx+1)*8-1 downto byte_select.idx*8) <= rx_dat_i;
					elsif receive_type = receive_gpo_bits then
						gpo_bits((byte_select.idx+1)*8-1 downto byte_select.idx*8) <= rx_dat_i;
					end if;
					-- handle the shifting of the byte-select-bitfield and detect end condition
					byte_select <= next_byte_select(byte_select);
					if byte_select.mask(3 downto 1) = "000" then
						state <= s_idle;
					end if;
				end if;

			when s_stb =>
				if wbta_stall_i = '0' then
					wbta_stb_out <= '0';
					wb_adr <= std_logic_vector(signed(wb_adr) + 4*to_integer(delta_adr));
					state <= s_idle;
				end if;

		end case;

	end process;
end architecture;



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;


-- Transfrom incoming wishbone transaction responses
-- into a byte stream that can be digested by uart transmitter
entity wbta_uart is 
port (
	clk_i    :  in std_logic;
	rst_i    :  in std_logic;
	-- uart receiver interface
	tx_dat_o   : out std_logic_vector(7 downto 0);
	tx_stb_o   : out std_logic;
	tx_stall_i :  in std_logic;
	-- wishbone transaction interface
	wbta_dat_i   :  in t_wbp_transaction_response;
	wbta_stb_i   :  in std_logic;
	wbta_stall_o : out std_logic
	);
end entity;

architecture rtl of wbta_uart is
	function response_type(ack, err, rty, stall_timeout : std_logic) return std_logic_vector is 
	begin
			 if           ack = '1' then return "001"; -- 1
		elsif           err = '1' then return "010"; -- 2
		elsif           rty = '1' then return "011"; -- 3
		elsif stall_timeout = '1' then return "100"; -- 4
		else                           return "000";
		end if;
	end function;

	type t_state is (s_idle, s_write_header, s_read_header, s_read_data);
	signal state : t_state := s_idle;

	--signal wbta_stall_out : std_logic := '0';
	signal tx_dat_out : std_logic_vector( 7 downto 0) := (others => '0');
	signal tx_stb_out : std_logic := '0';


	signal wb_dat : t_wbp_dat := (others => '0');
	signal wb_sel : t_wbp_dat := (others => '0');


	signal byte_select : t_byte_select := c_byte_select_zero;
begin

	wbta_stall_o <= '0' when state = s_idle else '1';
	tx_dat_o     <= tx_dat_out;
	tx_stb_o     <= tx_stb_out;

	process
		variable byte_select_next : t_byte_select;
	begin
		wait until rising_edge(clk_i);

		if rst_i = '1' then
			state       <= s_idle;
			tx_dat_out  <= (others => '0');
			tx_stb_out  <= '0';
			wb_dat      <= (others => '0');
			wb_sel      <= (others => '0');
			byte_select <= c_byte_select_zero;

		else

			case state is
				when s_idle =>
					if wbta_stb_i = '1' then 
						wb_dat      <= wbta_dat_i.dat;
						tx_stb_out  <= '1';
						if wbta_dat_i.we = '1' then 
							tx_dat_out <= '1' & "000" & '0' & response_type(wbta_dat_i.ack, wbta_dat_i.err, wbta_dat_i.rty, wbta_dat_i.stall_timeout);
							state      <= s_write_header;
						else 
							tx_dat_out <= '1' & response_type(wbta_dat_i.ack, wbta_dat_i.err, wbta_dat_i.rty, wbta_dat_i.stall_timeout) & wbta_dat_i.dat(31) & wbta_dat_i.dat(23) & wbta_dat_i.dat(15) & wbta_dat_i.dat(7);
							state      <= s_read_header;
						end if;
					end if; 

				when s_write_header =>
					if tx_stall_i = '0' then
						tx_stb_out <= '0';
						state <= s_idle;
					end if;

				when s_read_header =>
					if tx_stall_i = '0' then
						byte_select_next := init_byte_select(wbta_dat_i.sel);
						byte_select <= byte_select_next;
						tx_dat_out <= '0' & wb_dat((byte_select_next.idx+1)*8-2 downto byte_select_next.idx*8);
						if byte_select_next.mask = "0000" then 
							tx_stb_out <= '0';
							state <= s_idle;
						else 
							state <= s_read_data;
						end if;
					end if;

				when s_read_data =>
					if tx_stall_i = '0' then
						byte_select_next := next_byte_select(byte_select);
						if byte_select_next.mask = "0000" then 
							tx_stb_out <= '0';
							state <= s_idle;
						end if;
						byte_select <= byte_select_next;
						tx_dat_out <= '0' & wb_dat((byte_select_next.idx+1)*8-2 downto byte_select_next.idx*8);
					end if;				

			end case;

		end if;

	end process;

end;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wbta_pkg.all;

-- A wishbone slave interface with read and write capability
entity wb_uart is 
port (
	clk_i    :  in std_logic;
	rst_i    :  in std_logic;
	-- separate bridge reset from host that is used to get the state machine out of s_wait_for_host_response
	bridge_reset_i          :  in std_logic;
	-- host response
	config_write_response_i :  in std_logic;
	stb_resp_i              :  in t_wbp_response;
	-- uart transmitter interface
	tx_dat_o   : out std_logic_vector(7 downto 0);
	tx_stb_o   : out std_logic;
	tx_stall_i :  in std_logic;
	-- wishbone slave interface
	dat_i    :  in std_logic_vector(31 downto 0);
	adr_i    :  in std_logic_vector(31 downto 0);
	sel_i    :  in std_logic_vector( 3 downto 0);
	cyc_i    :  in std_logic;
	stb_i    :  in std_logic;
	we_i     :  in std_logic;
	stall_o  : out std_logic;
	ack_o    : out std_logic;
	rty_o    : out std_logic;
	err_o    : out std_logic;
	dat_o    : out std_logic_vector(31 downto 0)
);
end entity;

architecture rtl of wb_uart is
	
	signal tx_dat_out : std_logic_vector(7 downto 0) := (others => '0');
	signal tx_stb_out : std_logic := '0';

	signal wbp_resp_out : t_wbp_response := c_wbp_response_init;

	signal wb_dat : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_adr : std_logic_vector(31 downto 0) := (others => '0');
	signal wb_sel : std_logic_vector( 3 downto 0) := (others => '0');
	signal wb_we  : std_logic := '0';

	signal adr_packing : t_adr_packing := c_adr_packing_init;

	type t_state is  (s_idle, 
										s_write_header, s_adr, s_finish_read_adr, 
										s_prepare_write_data, s_write_data, 
										s_wait_for_host_response
										);
	signal state : t_state := s_idle;

	signal byte_select : t_byte_select := c_byte_select_zero;

	signal lowest_adr_bit_read : integer := 0;


	-- The slave produces two types of headers (type field 5 or 7)
	-- Type 5 is a slave write access, causing the wb-write callback function on the host to be called
	-- Type 7 is a slave read access, causing the wb-read callback funciton on the host to be called
	-- A variable number of bytes can follow a type 5 header, depending on the sel-bits and the length of the address
	-- header type 5 "1 101 ssss" "00aadddd" "0ddddddd" "0ddddddd" "0ddddddd" "0ddddddd"
	-- header type 5 "1 101 ssss" "01aadddd" "00aaaaaa" "0ddddddd" "0ddddddd" "0ddddddd" "0ddddddd"
	--                                 ........................
	-- header type 5 "1 101 ssss" "01aadddd" "01aaaaaa" "01aaaaaa" "01aaaaaa" "01aaaaaa" "00--aaaa" "0ddddddd" "0ddddddd" "0ddddddd" "0ddddddd"
	--                              / \             \\                                       /   \
	--                             /   adr bit 2    \ adr bit 4                    adr bit 31      adr bit 26
		--                       adr bit 3              adr bit 5
		--
	-- not yet implmeneted fast write (writes with sel = "1111" and without address) response type 6 header "1 110 dddd" "0ddddddd" "0ddddddd" "0ddddddd" "0ddddddd"

	-- slave reads
	-- header type 7 "1 111 ssss" "00aaaaaa" 
	--                                        ...
	-- header type 7 "1 111 ssss" "01aaaaaa" "01aaaaaa" "01aaaaaa" "01aaaaaa" "00aaaaaa"

begin
	tx_dat_o <= tx_dat_out;
	tx_stb_o <= tx_stb_out;

	stall_o  <= '0' when state = s_idle else '1';
	ack_o    <= wbp_resp_out.ack;
	rty_o    <= wbp_resp_out.rty;
	err_o    <= wbp_resp_out.err;
	dat_o    <= wbp_resp_out.dat;


	process
		variable byte_select_next : t_byte_select;
	begin
		wait until rising_edge(clk_i);

		if rst_i = '1' then

			tx_dat_out     <= (others => '0');
			tx_stb_out     <= '0';
			wbp_resp_out   <= c_wbp_response_init;
			wb_dat         <= (others => '0');
			wb_adr         <= (others => '0');
			wb_sel         <= (others => '0');
			wb_we          <= '0';
			state          <= s_idle;
			byte_select    <= c_byte_select_zero;
			lowest_adr_bit_read <= 0;

		else

			wbp_resp_out <= c_wbp_response_init;

			case state is 
				when s_idle =>
					if cyc_i = '1' and stb_i = '1' then 
						if we_i = '1' then
							wb_dat <= dat_i;
							wb_adr <= adr_i;
							wb_sel <= sel_i;
							wb_we  <= '1';
							wbp_resp_out.ack <= not config_write_response_i; -- don't ack if a write response from the host is expected
							tx_stb_out <= '1';
							if config_write_response_i = '1' then
								tx_dat_out <= "1101" & sel_i;
							else 
								tx_dat_out <= "1110" & sel_i;
							end if;
							adr_packing <= init_adr_packing_write(adr_i);
							state <= s_write_header;
						else 
							wb_adr <= adr_i;
							wb_sel <= sel_i;
							wb_we  <= '0';
							wbp_resp_out.ack <= '0';
							tx_stb_out <= '1';
							tx_dat_out <= "1111" & sel_i;
							adr_packing <= init_adr_packing_read(adr_i);
							state <= s_adr;
						end if;
					else
						tx_stb_out <= '0';
					end if;

				when s_write_header =>
					if tx_stall_i = '0' then
						if adr_packing_more_adr_blocks(adr_packing) then
							tx_dat_out <= '0' & '1' & wb_adr(3 downto 2) & wb_dat(31) & wb_dat(23) & wb_dat(15) & wb_dat(7);
							state <= s_adr;
						else
							tx_dat_out <= '0' & '0' & wb_adr(3 downto 2) & wb_dat(31) & wb_dat(23) & wb_dat(15) & wb_dat(7);
							state <= s_prepare_write_data;
						end if;
					end if;

				when s_adr =>
					if tx_stall_i = '0' then
						if adr_packing_more_adr_blocks(adr_packing) then
							adr_packing.idx <= adr_packing.idx + 1;
							tx_dat_out <= '0' & '1' & adr_packing.blocks(adr_packing.idx);
						else
							tx_dat_out <= '0' & '0' & adr_packing.blocks(adr_packing.idx);
							if wb_we = '1' then
								state <= s_prepare_write_data;
							else 
								state <= s_finish_read_adr;
							end if;
						end if;
					end if;

				when s_finish_read_adr =>
					if tx_stall_i = '0' then 
						state <= s_wait_for_host_response;
					end if;

				when s_prepare_write_data =>	
					if tx_stall_i = '0' then
						byte_select_next := init_byte_select(wb_sel);
						byte_select <= byte_select_next;
						
						tx_dat_out <= '0' & wb_dat((byte_select_next.idx+1)*8-2 downto byte_select_next.idx*8);
						if byte_select_next.mask = "0000" then 
							tx_stb_out <= '0';
							if config_write_response_i = '1' then
								state <= s_wait_for_host_response;
							else
								state <= s_idle;
							end if;
						else
							state <= s_write_data;
						end if;
					end if;

				when s_write_data =>
					if tx_stall_i = '0' then 
						byte_select_next := next_byte_select(byte_select);
						byte_select <= byte_select_next;

						tx_dat_out <= '0' & wb_dat((byte_select_next.idx+1)*8-2 downto byte_select_next.idx*8);
						if byte_select_next.mask = "0000" then 
							tx_stb_out <= '0';
							if config_write_response_i = '1' then
								state <= s_wait_for_host_response;
							else
								state <= s_idle;
							end if;
						end if;
					end if;

				when s_wait_for_host_response =>
					tx_stb_out <= '0';
					if bridge_reset_i = '1' then
						wbp_resp_out <= c_wbp_response_init;
						state <= s_idle;
					else 
						if stb_resp_i.ack = '1' or stb_resp_i.err = '1' or stb_resp_i.rty = '1' then
							wbp_resp_out <= stb_resp_i;
							state <= s_idle;
						end if;
					end if;

			end case;

		end if;

	end process;

end architecture;
