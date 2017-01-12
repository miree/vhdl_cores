library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

use work.delay_pkg.all;

entity delay_tb is
end entity;

architecture simulation of delay_tb is
  constant clk_period : time := 5 ns;

  -- generics for the device under test
  constant test_depth     : integer := 7; -- delay length of 2^3
  constant test_bit_width : integer := 8;

  -- signals to connect to fifo
  signal clk  : std_logic;
  signal rst  : std_logic;
  signal d,q  : std_logic_vector ( test_bit_width-1 downto 0 ) := (others => '0');

begin

  -- instantiate device under test (dut)
  dut : work.delay_pkg.delay
    generic map (
      depth     => test_depth,
      bit_width => test_bit_width
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      d_i     => d,
      q_o     => q
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

  count: process(clk)
  begin
    if rising_edge(clk) then
      d <= std_logic_vector(unsigned(d) + x"01");
    end if;
  end process;



end architecture;