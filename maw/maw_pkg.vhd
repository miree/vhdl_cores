library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package maw_pkg is

component maw
  generic (
    depth            : integer;
    buffer_bit_width : integer
  );
  port (
    clk_i , rst_i   : in  std_logic;
    value_i         : in  unsigned ( buffer_bit_width-1 downto 0 );
    value_o         : out unsigned ( buffer_bit_width+depth-1 downto 0 )
  );
end component;

end package; 

package body maw_pkg is

end package body;