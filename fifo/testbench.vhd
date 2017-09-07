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
  constant clk_period : time := 5 ns;
  -- signals to connect to fifo
  constant depth     : integer := 3;  -- the number of fifo entries is 2**depth
  constant bit_width : integer := 32; -- number of bits in each entry
  signal clk, rst    : std_logic;
  signal d, q        : std_logic_vector ( bit_width-1 downto 0 );
  signal push, pop   : std_logic;
  signal full, empty : std_logic;
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
      clk_i   => clk,
      rst_i   => rst,
      d_i     => d,
      q_o     => q,
      push_i  => push,
      pop_i   => pop,
      full_o  => full,
      empty_o => empty
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
    rst <= '0';
    wait for clk_period*20;
    rst <= '1';
    wait;
  end process;

  p_read_write : process
  begin
    push <= '0';
    pop  <= '0';

    --=============================
    -- fill fifo
    --=============================
      wait for clk_period*40;
    for i in 0 to 2 loop
      -- convert an integer into std_logic_vector
      -- i_slv := std_logic_vector(to_unsigned(i,8));
      d    <= ctr;
      push <= '1';
        wait for clk_period;
      push <= '0';
        wait for clk_period*5;
    end loop;
    --=============================
    -- empty fifo
    --=============================
      wait for clk_period*40;
    for i in 0 to 3 loop
      pop <= '1';
        wait for clk_period;
      pop <= '0';
        wait for clk_period*5;
        --expected := std_logic_vector(unsigned(expected) + 1);
                    -- typecasts can be avoided when using the library use ieee.std_logic_unsigned.all;
    end loop;
  end process;

  check: process
  begin
    wait until rising_edge(clk);
    if empty = '0' and pop = '1' then
      assert unsigned(q) = unsigned(expected)
            report "We didn't get what we expect (" 
              & integer'image(to_integer(unsigned(q))) 
              & " /= "
              & integer'image(to_integer(unsigned(expected)))
              & ")";
    end if;
  end process;


  -- this process increments the counter (that is the value which is written to the fifo)
  -- only on rising clock edges when the acknowledge signal was sent back from the fifo, i.e.
  -- if a value was successfully pushed into the fifo.
  p_increment_ctr : process(clk)
  begin
  	if rising_edge(clk) then
  		if full = '0' and push = '1' then
  			ctr <= std_logic_vector(unsigned(ctr) + 1);
  		end if;
  	end if;
  end process;

  p_increment_expected : process(clk)
  begin
  	if rising_edge(clk) then
  		if empty = '0' and pop = '1' then
  			expected <= std_logic_vector(unsigned(expected) + 1);
  		end if;
  	end if;
  end process;

end architecture;