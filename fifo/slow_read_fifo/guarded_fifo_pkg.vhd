library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package guarded_fifo_pkg is
  component guarded_fifo 
    generic (
      depth     : integer; 
      bit_width : integer
    );
  port (
    -- fast side interface
    clk_fast_i : in std_logic;
    rst_fast_i : in std_logic;
    push_i     : in  std_logic;
    full_o     : out std_logic;
    d_i        : in  std_logic_vector ( bit_width-1 downto 0 );

    -- slow side interface
    clk_i      : in  std_logic;
    rst_i      : in  std_logic;
    dack_i     : in  std_logic;
    drdy_o      : out std_logic;
    q_o        : out std_logic_vector ( bit_width-1 downto 0 )
  );
  end component; 

end package; 

