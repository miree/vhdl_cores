library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- package with component to test on this testbench
use work.fifo_pkg.all;
use work.guarded_fifo_pkg.all;

entity testbench is
end entity;

architecture simulation of testbench is
  -- clock generation
  constant clk_period      : time := 20  ns;
  constant clk_fast_period : time := 4 ns;
  -- signals to connect to fifo
  constant depth     : integer := 2;  -- the number of fifo entries is 2**depth
  constant bit_width : integer := 32; -- number of bits in each entry
  signal clk_fast    : std_logic;
  signal clk         : std_logic;
  signal rst_fast    : std_logic;
  signal rst         : std_logic;
  signal d, q        : std_logic_vector ( bit_width-1 downto 0 );
  signal push, data_acknowledge   : std_logic;
  signal full, data_ready : std_logic;
  -- the value that is pushed to the fifo
  signal ctr         : std_logic_vector ( bit_width-1 downto 0 ) := (others => '0');
  -- the value that is expected to be read from the fifo (initialized with -1)
  signal expected    : std_logic_vector ( bit_width-1 downto 0 ) := (others => '0');

begin
  -- instantiate device under test (dut)
  dut : work.guarded_fifo_pkg.guarded_fifo
    generic map (
      depth     => depth ,
      bit_width => bit_width
    )
    port map (
      clk_fast_i => clk_fast,
      clk_i      => clk,
      rst_fast_i => rst_fast,
      rst_i      => rst,
      d_i        => ctr,
      q_o        => q,
      push_i     => push,
      dack_i     => data_acknowledge,
      full_o     => full,
      drdy_o      => data_ready
    );

  clk_gen: process
  begin
    clk <= '0';
    wait for clk_period/2; 
    clk <= '1';
    wait for clk_period/2;
  end process;

  clk_fast_gen: process
  begin
    wait for 0.567 ns;
    for i in 0 to 1000000000 loop
      clk_fast <= '0';
      wait for clk_fast_period/2; 
      clk_fast <= '1';
      wait for clk_fast_period/2;
    end loop;
  end process;

  rst_initial: process
  begin
    rst <= '1';
    rst_fast <= '1';
    wait for clk_period*20;
    rst <= '0';
    rst_fast <= '0';
    wait;
  end process;

  p_read_write : process
  begin
    push <= '0';
    --=============================
    -- fill fifo
    --=============================
      --wait for clk_period*40.5;
    wait until falling_edge(rst);
    for i in 0 to 10000 loop
      wait until rising_edge(clk_fast);
      push <= not push;
    end loop;
  end process;


  p_read: process
  begin
    data_acknowledge <= '0';
    for i in 0 to 10000 loop
      wait until data_ready = '1';
      wait for clk_period;
      data_acknowledge <= '1';
      wait for clk_period;
      data_acknowledge <= '0';
    end loop;
  end process;

  -- this process increments the counter (that is the value which is written to the fifo)
  -- only on rising clock edges when the acknowledge signal was sent back from the fifo, i.e.
  -- if a value was successfully pushed into the fifo.
  p_increment_ctr : process(clk_fast)
  begin
    if rising_edge(clk_fast) then
      if full = '0' and push = '1' then
        ctr <= std_logic_vector(unsigned(ctr) + 1);
      end if;
    end if;
  end process;

end architecture;