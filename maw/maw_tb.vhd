library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

use work.maw_pkg.all;

entity maw_tb is
end entity;

architecture simulation of maw_tb is
  constant clk_period : time := 5 ns;

  constant test_depth     : integer := 6;
  constant test_bit_width : integer := 8;

  signal input_value  : unsigned (test_bit_width-1 downto 0);
  signal output_value : unsigned (test_bit_width+test_depth-1 downto 0);

  -- signals to connect to fifo
  signal clk  : std_logic;
  signal rst  : std_logic;

begin

  -- instantiate device under test (dut)
  dut : entity work.maw
    generic map (
      depth           => test_depth,
      input_bit_width => test_bit_width
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      value_i => input_value,
      value_o => output_value
    );  

  clk_gen: process
  begin
    clk <= '0';
    wait for clk_period/2; 
    clk <= '1';
    wait for clk_period/2;

  end process;

  rst_initial: process
  begin
    rst <= '1';
    wait for clk_period*20;
    rst <= '0';
    wait;
  end process;

  gen_input: process(clk, rst)
   variable counter    : integer := 0;
   variable add        : integer := 200;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        counter := 0;
        input_value <= (others => '0');
      else
        counter := counter + 1;
        if counter mod 100 = 0 then
          -- do a manual mod operation to avoid truncation warning
          input_value <= to_unsigned((to_integer(input_value) + add) mod input_value'length, input_value'length);
          add := add + 221;
        else
          input_value <= input_value;
        end if;
      end if;
    end if;
  end process;

end architecture;