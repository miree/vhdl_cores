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
  --  by looking at the most significant bit (tip from Mathias Kreider)
  signal w_idx     : unsigned ( depth downto 0 );
  signal r_idx     : unsigned ( depth downto 0 );

  signal msb_xor       : std_logic;
  signal empty_or_full : boolean;
  signal empty         : std_logic;
  signal full          : std_logic;
  signal q             : std_logic_vector ( bit_width-1 downto 0 );


begin
  main: process
  begin
    wait until rising_edge(clk_i);
    if rst_i = '1' then 
      w_idx   <= (others => '0'); 
      r_idx   <= (others => '0');
    else
       -- write
      if push_i = '1' then
        fifo_data(to_integer(w_idx(depth-1 downto 0))) <= d_i;
        w_idx <= w_idx + 1;
      end if;
      -- read
      if pop_i = '1' then
        r_idx <= r_idx + 1; 
      end if;
      -- synchronous output to allow inference of block ram
      if push_i = '1' and empty = '1' then
        q <= d_i;
        report "push output";
      elsif pop_i = '1' then
        q <= fifo_data(to_integer(r_idx(depth-1 downto 0)+1));
        report "pop output";
      else
        q <= fifo_data(to_integer(r_idx(depth-1 downto 0)));
      end if;
    end if;
  end process;

  -- If read and write index up to (not including) the most significant bit are identical,
  --  the fifo is either empty or full.
  -- The xor of the most significant bit decides if the fifo is full or empty.
  msb_xor       <= (r_idx(depth) xor w_idx(depth));
  empty_or_full <= r_idx(depth-1 downto 0) = w_idx(depth-1 downto 0);

  full       <=     msb_xor when empty_or_full else '0';
  full_o     <= full;
  empty      <= not msb_xor when empty_or_full else '0';
  empty_o    <= empty;

  -- for simulations it is more obvious if an empty fifo has 'u' on output
  q_o        <= (others => 'U') when empty = '1' else q;

end architecture;