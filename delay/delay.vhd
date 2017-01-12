library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay is
  generic (
    depth     : integer;
    bit_width : integer
  );
  port (
    clk_i , rst_i   : in  std_logic;
    d_i             : in  std_logic_vector ( bit_width-1 downto 0 );
    q_o             : out std_logic_vector ( bit_width-1 downto 0 )
  );
end entity;

architecture rtl of delay is
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
  signal w_idx     : std_logic_vector ( depth downto 0 );
  signal r_idx     : std_logic_vector ( depth downto 0 );
begin
  main: process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        -- force reset state
        w_idx   <= (others => '0');
        r_idx   <= (others => '0');
        q_o     <= (others => '0');
      else
        --  writing
        fifo_data(to_integer(unsigned(w_idx(depth-1 downto 0)))) <= d_i;
        w_idx <= std_logic_vector(unsigned(w_idx) + 1);
        --  reading
        r_idx <= r_idx;
        q_o   <= (others => '0');
        if (r_idx(depth) xor w_idx(depth)) = '1' then
          q_o   <= fifo_data(to_integer(unsigned(r_idx(depth-1 downto 0))));
          r_idx <= std_logic_vector(unsigned(r_idx) + 1);
        end if;

      end if;

    end if;
  end process;
end architecture;