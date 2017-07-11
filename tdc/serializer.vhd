library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

entity serializer is 
  generic (
    in_width  : integer;
    out_width : integer;
    depth     : integer
  );
  port ( 
    clk_i , rst_i   : in  std_logic;
    push_i, pop_i   : in  std_logic;
    full_o, empty_o : out std_logic;
    d_i             : in  std_logic_vector ( in_width-1  downto 0 );
    q_o             : out std_logic_vector ( out_width-1 downto 0 )
  ); 
end entity; 

architecture rtl of serializer is
  signal pop         : std_logic;
  signal out_data    : std_logic_vector ( in_width-1 downto 0 );
  constant idx_max   : integer := in_width/out_width-1;
  constant idx_width : integer := integer(ceil(log2(real(idx_max+1))));
  signal idx         : unsigned ( idx_width-1 downto 0 ) := (others => '0');
begin

  fifo: entity work.fifo
    generic map (
        depth     => depth,
        bit_width => in_width
      )
    port map (
      clk_i   => clk_i,
      rst_i   => rst_i,
      push_i  => push_i,
      pop_i   => pop,
      full_o  => full_o,
      empty_o => empty_o,
      d_i     => d_i,
      q_o     => out_data
    );

  main : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        idx <= (others => '0');
      else
        if pop_i = '1' then 
          if idx = idx_max then 
            idx <= (others => '0');
          else
            idx <= idx + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
  
  --q_o <= out_data(out_width*(to_integer(idx)+1)-1 downto out_width*to_integer(idx)); 
  q_o <= out_data(out_width*(idx_max+1-to_integer(idx))-1 downto out_width*(idx_max-to_integer(idx))); 

  pop <= '1' when pop_i = '1' and idx = idx_max else '0';


end architecture;