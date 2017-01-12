library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity guarded_fifo is
  generic (
    depth     : integer;
    bit_width : integer
  );
  port (
    clk_i , rst_i   : in std_logic;
    push_i, pop_i   : in  std_logic;
    full_o, empty_o : out std_logic;
    d_i             : in  std_logic_vector ( bit_width-1 downto 0 );
    q_o             : out std_logic_vector ( bit_width-1 downto 0 )
  );
end entity;

-- Take a non-guarded fifo and take control over the
-- push and pull lines and prevent illegal operations. 
-- Forward the full and empty signals are forwarded.
use work.fifo_pkg.all;
architecture rtl of guarded_fifo is
  signal push, pop, full, empty   : std_logic;
begin
  fifo : work.fifo_pkg.fifo 
  generic map (
    depth     => depth,
    bit_width => bit_width
  )
  port map (
    clk_i   => clk_i,
    rst_i   => rst_i,
    push_i  => push,
    pop_i   => pop,
    full_o  => full,
    empty_o => empty,
    d_i     => d_i,
    q_o     => q_o
  );

  full_o  <= full;
  empty_o <= empty;

  push    <= push_i and not full;
  pop     <= pop_i  and not empty;
  
end architecture;