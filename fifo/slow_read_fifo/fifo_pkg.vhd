library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- fifo with synchronous read -> using block ram
package fifo_pkg is
  component fifo 
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
  end component; 

end package; 

package body fifo_pkg is

end package body;