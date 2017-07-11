library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity delayline is
	generic (
		length : integer
	);	
	port ( clk_i     : in  std_logic;
		   rst_i     : in  std_logic;
		   async_i   : in  std_logic;
		   line_o    : out std_logic_vector(length-1 downto 0);
		   signal_o  : out std_logic
		  );
end entity;

architecture rtl of delayline is
	signal delay_line            : std_logic_vector(length downto 0); 
	signal line_buffer_snap      : std_logic_vector(length downto 0);
	signal line_buffer           : std_logic_vector(length downto 0);
	signal edge_buffer           : std_logic_vector(length-1   downto 0);
	attribute KEEP               : string; 
	attribute KEEP of delay_line : signal is "true"; 
begin
	process(clk_i) is
	begin
		if rising_edge(clk_i) then
			line_buffer_snap <= delay_line;

			for i in edge_buffer'range loop 
				edge_buffer(i) <=     (not line_buffer_snap(i+1) xor line_buffer_snap(i));
			end loop;
			line_buffer <= line_buffer_snap;

			if unsigned(edge_buffer) /= 0 then
				line_o  <= line_buffer(length downto 1);
				signal_o <= '1';
			else
				line_o   <= (others => '0');
				signal_o <= '0';
			end if;

		end if;
	end process;
	
	process (delay_line, async_i) 
	begin
		for i in delay_line'range loop
			if i = delay_line'left then
				delay_line(i) <= async_i;
			else
				delay_line(i) <= not delay_line(i+1) after 330 ps;
			end if;
		end loop;
	end process;
end architecture;

