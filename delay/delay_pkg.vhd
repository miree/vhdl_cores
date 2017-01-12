library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package delay_pkg is

component delay
  generic (
    depth     : integer;
    bit_width : integer
  );
  port (
    clk_i , rst_i   : in  std_logic;
    d_i             : in  std_logic_vector ( bit_width-1 downto 0 );
    q_o             : out std_logic_vector ( bit_width-1 downto 0 )
  );
end component;

end package; 

package body delay_pkg is

end package body;