library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is 
  generic (
    depth     : integer;
    bit_width : integer
  );
  port ( 
    clk_i , rst_i   : in  std_logic;
    push_i, pop_i   : in  std_logic;
    full_o, empty_o : out std_logic;
    d_i             : in  std_logic_vector ( bit_width-1 downto 0 );
    q_o             : out std_logic_vector ( bit_width-1 downto 0 )
  ); 
end entity; 

architecture rtl of fifo is
  -- calculate the number of words from 
  --   the depth (which is like the address width)
  constant number_of_words : integer := 2**depth;
  -- define data type of the storage array
  type fifo_data_array is array ( 0 to number_of_words-1) 
            of std_logic_vector ( bit_width-1 downto 0);
  -- define the storage array          
  signal fifo_data : fifo_data_array;
  -- read and write index pointers
  --  give them one bit more then needed to quickly check for overflow
  --  by looking at the most significant bit (tip from Matthias Kreider)
  signal w_idx     : unsigned ( depth downto 0 );
  signal r_idx     : unsigned ( depth downto 0 );
begin

  main: process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then -- reset is active high
        -- force reset state
        w_idx   <= (others => '0'); 
        r_idx   <= (others => '0');
      else
        -- normal operation:
        --  writing
        if push_i = '1' then
          fifo_data(to_integer(w_idx(depth-1 downto 0))) <= d_i;
          w_idx <= w_idx + 1;
        end if;
        --  reading
        if pop_i = '1' then
          r_idx <= r_idx + 1; 
        end if;
      end if;
    end if;
  end process;

  q_o     <= fifo_data(to_integer(r_idx(depth-1 downto 0)));
  full_o  <=      r_idx(depth) xor w_idx(depth)  when (r_idx(depth-1 downto 0) = w_idx(depth-1 downto 0)) else '0';
  empty_o <= not (r_idx(depth) xor w_idx(depth)) when (r_idx(depth-1 downto 0) = w_idx(depth-1 downto 0)) else '0';

end architecture;