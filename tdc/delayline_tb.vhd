library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

entity delayline_tb is
end entity;

architecture simulation of delayline_tb is
  constant clk_period : time := 20 ns;

  -- generics for the device under test
  --constant test_depth     : integer := 7; -- delay length of 2^3
  --constant test_bit_width : integer := 8;

  -- signals to connect to fifo
  signal clk         : std_logic;
  signal rst         : std_logic;
  signal async       : std_logic;
  signal line_result : std_logic_vector (63 downto 0) := (others => '0');
  signal send_data   : std_logic_vector (127 downto 0) := (others => '0');
  signal edge_detected : std_logic;
  signal pop         : std_logic;
  signal fifo_out    : std_logic_vector (7 downto 0) := (others => '0');
  signal full, empty : std_logic;
  signal counter     : unsigned (63 downto 0) := (others => '0');
begin

  --fifo : entity work.fifo
  --  generic map (
  --      depth     => 6,
  --      bit_width => 64
  --    )
  --  port map (
  --    clk_i   => clk,
  --    rst_i   => rst,
  --    push_i  => edge_detected,
  --    pop_i   => pop,
  --    full_o  => full,
  --    empty_o => empty,
  --    d_i     => line_result,
  --    q_o     => fifo_out
  --  );

  serial : entity work.serializer
    generic map (
        in_width  => 2*64,
        out_width => 8,
        depth     => 4
      )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      push_i  => edge_detected,
      pop_i   => pop,
      full_o  => full,
      empty_o => empty,
      d_i     => send_data,
      q_o     => fifo_out
    );   

    send_data <= std_logic_vector(counter) & line_result;

  -- instantiate device under test (dut)
  dut : entity work.delayline
    generic map (
        length => 64
      )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      async_i  => async,
      line_o   => line_result,
      signal_o => edge_detected
    );

  count: process (clk)
  begin
    if rising_edge(clk) then 
      if rst = '1' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;  

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

  async_gen: process
  begin
    async <= '0';
    wait for 403.4 ns;
    async <= not async;
    wait for 5.2 ns;
    async <= not async;
    wait for 201.1 ns;
    async <= not async;
    wait for 47.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 77.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 47.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 77.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 47.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait for 77.6 ns;
    async <= not async;
    wait for 7.6 ns;
    async <= not async;
    wait;
  end process;


  pop <= not empty;
  --pop_gen: process
  --begin
  --  pop <= '0';
  --  wait for 610 ns;
  --  pop <= '1';
  --  wait;
  --end process;


end architecture;