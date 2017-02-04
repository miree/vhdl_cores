library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity maw is
  generic (
    -- window width is 2^depth
    depth           : integer;
    input_bit_width : integer
  );
  port (
    clk_i , rst_i   : in  std_logic;
    value_i         : in  unsigned ( input_bit_width-1 downto 0 );
    -- the ouput value's maximum is 2^input_bit_width * 2^depth
    value_o         : out unsigned ( input_bit_width+depth-1 downto 0 )
  );
end entity;

architecture rtl of maw is
  signal delayed       : std_logic_vector ( input_bit_width-1 downto 0 );
  signal sum           : unsigned (input_bit_width+depth-1 downto 0); 
  signal add, sub      : unsigned (input_bit_width+depth-1 downto 0);

begin

  buf : entity work.delay
    generic map (
      depth     => depth,
      bit_width => input_bit_width
    )
    port map (
      clk_i   => clk_i,
      rst_i   => rst_i,
      q_o     => delayed, -- type conversion only works for inputs (see line below)
                          --   so here an additional signal is used for type matching
      d_i     => std_logic_vector(value_i) 
    );

  process (clk_i)
    variable leading_zeros : unsigned (depth-1 downto 0) := (others => '0');
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        value_o <= (others => '0');
        sum     <= (others => '0');
        sub     <= (others => '0');
        add     <= (others => '0');
      else

        add <= leading_zeros & value_i ;
        sub <= leading_zeros & unsigned(delayed);

        -- here it is imporatant to do the subtraction first,
        --  otherwise the intermediate value can overflow (be greater than 2^input_bit_width * 2^depth) 
        sum <= sum - sub + add;
        value_o <= sum;
      end if;
    end if;
  end process;


end architecture;