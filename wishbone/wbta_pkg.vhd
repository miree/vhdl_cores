library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wbta_pkg is

	constant c_wbp_adr_width : integer := 32;
	constant c_wbp_dat_width : integer := 32;

	subtype t_wbp_adr is
		std_logic_vector(c_wbp_adr_width-1 downto 0);
	subtype t_wbp_dat is
		std_logic_vector(c_wbp_dat_width-1 downto 0);
	subtype t_wbp_sel is
		std_logic_vector((c_wbp_adr_width/8)-1 downto 0);

	type t_wbp_transaction_request is record
		stall_timeout : unsigned(31 downto 0); -- wait at most so long for stall to go down before ending the strobe
		cyc : std_logic;
		adr : t_wbp_adr;
		sel : t_wbp_sel;
		we  : std_logic;
		dat : t_wbp_dat;
	end record;
	constant c_wbp_transaction_init   : t_wbp_transaction_request   := (stall_timeout=>(others => '0'), cyc=>'0',we=>'0',adr=>(others=>'-'),dat=>(others=>'-'),sel=>(others=>'-'));
	type t_wbta_request is record
		dat   : t_wbp_transaction_request;
		stb   : std_logic;
		stall : std_logic;
	end record;
	constant c_wbta_request_init : t_wbta_request := (c_wbp_transaction_init, '0', '0');  
	type t_wbp_transaction_response is record
		sel : t_wbp_sel;
		dat : t_wbp_dat;
		we  : std_logic;
		ack : std_logic;
		err : std_logic;
		rty : std_logic;
		stall_timeout : std_logic; -- this is '1' when the strobe was stalled for too long
	end record;
	constant c_wbp_transaction_response_init  : t_wbp_transaction_response := (sel=>(others=>'0'),dat=>(others=>'0'),we=>'0',ack=>'0',err=>'0',rty=>'0',stall_timeout=>'0');
	type t_wbta_response is record
		dat   : t_wbp_transaction_response;
		stb   : std_logic;
		stall : std_logic;
	end record;
	constant c_wbta_response_init : t_wbta_response := (c_wbp_transaction_response_init, '0', '0');

	type t_wbp_response is record 
		dat  : t_wbp_dat;
		ack  : std_logic;
		err  : std_logic;
		rty  : std_logic;
	end record;
	constant c_wbp_response_init : t_wbp_response := (dat=>(others => '0'), others => '0');
	type t_configuration is record
		host_sends_write_response : std_logic;
		fpga_sends_write_response : std_logic;
	end record;
	constant c_configuration_init : t_configuration := (host_sends_write_response=>'0', fpga_sends_write_response=>'1');


	subtype t_byte_idx is integer range 0 to 3;
	type t_byte_select is record
		idx : t_byte_idx;
		mask: std_logic_vector(3 downto 0);
	end record;
	constant c_byte_select_zero : t_byte_select := (0,(others => '0'));

	function next_byte_select(byte : t_byte_select) return t_byte_select;
	function init_byte_select(init_mask : std_logic_vector(3 downto 0)) return t_byte_select;

	subtype t_adr_block_idx is integer range 0 to 4;
	type t_adr_blocks is array (0 to 4) of std_logic_vector(5 downto 0);
	type t_adr_packing is record
		idx    : t_adr_block_idx;
		mask   : std_logic_vector(0 to 4);
		blocks : t_adr_blocks;
	end record;
	constant c_adr_packing_init : t_adr_packing := (0, (others => '0'), (others => (others => '0')));

	function init_adr_packing_write(adr : std_logic_vector(31 downto 0)) return t_adr_packing;
	function init_adr_packing_read(adr : std_logic_vector(31 downto 0)) return t_adr_packing;
	function adr_packing_more_adr_blocks(adr_packing : t_adr_packing) return boolean;
end package;

package body wbta_pkg is

	-- shift-right a bit-mask until a '1' is at maks(0). 
	-- increase idx by how many bits were shifted.
	function next_byte_select(byte : t_byte_select) return t_byte_select is 
	begin
			 if byte.mask(1) = '1' then return  (byte.idx + 1,   "0" & byte.mask(3 downto 1));
		elsif byte.mask(2) = '1' then return  (byte.idx + 2,  "00" & byte.mask(3 downto 2));
		elsif byte.mask(3) = '1' then return  (byte.idx + 3, "000" & byte.mask(3));
		else                          return  c_byte_select_zero;
		end if;
	end function;
	function init_byte_select(init_mask : std_logic_vector(3 downto 0)) return t_byte_select is 
		variable start_byte : t_byte_select := (0, init_mask);
	begin
		if init_mask(0) = '1' then return start_byte; 
		else                       return next_byte_select(start_byte);
		end if;
	end function;

	function init_adr_packing_write(adr : std_logic_vector(31 downto 0)) return t_adr_packing is 
		variable result : t_adr_packing := c_adr_packing_init;
	begin
		for i in 0 to 3 loop 
			result.blocks(i) := adr(9+6*i downto 4+6*i);
		end loop;
		result.blocks(4)(5 downto 0) := "00" & adr(31 downto 28);
		for i in 0 to 4 loop 
			if result.blocks(i) = "000000" then 
				result.mask(i) := '0';
			else 
				result.mask(i) := '1';
			end if; 
		end loop;
		result.idx := 0;
		return result;
	end function;
	function init_adr_packing_read(adr : std_logic_vector(31 downto 0)) return t_adr_packing is 
		variable result : t_adr_packing := c_adr_packing_init;
	begin
		for i in 0 to 4 loop 
			result.blocks(i) := adr(7+6*i downto 2+6*i);
		end loop;
		for i in 0 to 4 loop 
			if result.blocks(i) = "000000" then 
				result.mask(i) := '0';
			else 
				result.mask(i) := '1';
			end if; 
		end loop;
		result.idx := 0;
		return result;
	end function;
	function adr_packing_more_adr_blocks(adr_packing : t_adr_packing) return boolean is 
	begin
		if adr_packing.idx = 4 then 
			return false; 
		end if;
		return unsigned(adr_packing.mask(adr_packing.idx to 4)) /= 0;
	end function;


end package body;

