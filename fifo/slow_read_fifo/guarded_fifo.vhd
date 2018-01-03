library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity guarded_fifo is
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
    drdy_o     : out std_logic;
    q_o        : out std_logic_vector ( bit_width-1 downto 0 )
  );
end entity;

-- Take a non-guarded fifo and take control over the
-- push and pull lines and prevent illegal operations. 
-- Forward the full and empty signals.
use work.fifo_pkg.all;
architecture rtl of guarded_fifo is
  -- fast side signal
  type fast_state_t is (s_idle, s_getting_data_pop, s_getting_data_nopop, s_getting_data_latch, s_providing_data, s_start_pop, s_unknown);
  signal full, empty, push, pop               : std_logic;
  signal pop_request_sync, pop_request_sync_1 : std_logic;
  signal q, fifo_out_data_fast                : std_logic_vector ( bit_width-1 downto 0 );
  signal data_ready                           : std_logic;
  signal state, next_state                    : fast_state_t;

  -- slow side signals
  type slow_state_t is (s_block, s_noblock);
  signal data_ready_sync, data_ready_sync_1 : std_logic;
  signal data_ready_block                    : std_logic;
  signal fifo_out_data_slow                 : std_logic_vector ( bit_width-1 downto 0 );
  signal slow_state                         : slow_state_t;

begin
  -- the fifo is located on the fast side
  fifo : work.fifo_pkg.fifo 
  generic map (
    depth     => depth,
    bit_width => bit_width
  )
  port map (
    clk_i   => clk_fast_i,
    rst_i   => rst_fast_i,
    push_i  => push,
    pop_i   => pop,
    full_o  => full,
    empty_o => empty,
    d_i     => d_i,
    q_o     => q
  );
  -- fast side interface of this module can be forwarded directly to the fifo
  full_o  <= full;
  push    <= push_i and not full;

  -- the fast side process has a state machine that manages popping data from the fifo if it is available
  -- 
  fast_side: process
  begin
    wait until rising_edge(clk_fast_i);
    if rst_fast_i = '1' then
      state <=  s_idle;
      next_state <= s_idle;
      fifo_out_data_fast <= (others => 'U');
      data_ready <= '0';
    else
      -- signal synchroinzation on the fast side (look at slow signals)
      pop_request_sync_1 <= dack_i; -- data acknowledge => we make a pop request to the underlying fifo
      pop_request_sync   <= pop_request_sync_1;

      fifo_out_data_fast <= fifo_out_data_fast;

      -- managing state machine
      case state is

        when s_idle => 
          if empty = '0' and pop_request_sync = '0' then 
            state <= s_getting_data_pop;
          else 
            state <= s_idle;
          end if;

        -- create a single pulse to get next data
        when s_getting_data_pop =>
          if empty = '1' then
            state <= s_idle;
          else
            pop <= '1';
            state <= s_getting_data_nopop;
          end if;
        when s_getting_data_nopop =>
          pop <= '0';
          data_ready <= '1';
          state <= s_getting_data_latch;

        when s_getting_data_latch =>
          state <= s_providing_data;
          fifo_out_data_fast <= q;
          data_ready <= '1';

        when s_providing_data =>
          if pop_request_sync = '1' then
            state <= s_start_pop;
            data_ready <= '0';
          end if;
        when s_start_pop =>
          if pop_request_sync = '0' then
            state <= s_idle;
          end if;

        when others => state <= s_unknown;        

      end case;
    end if;
  end process;


  slow_side: process 
  begin    
    wait until rising_edge(clk_i);
    if rst_i = '1' then
      drdy_o             <= '0';
      data_ready_sync_1 <= '0';
      data_ready_sync   <= '0';
      q_o               <= (others => 'U');
      data_ready_block  <= '0';
      slow_state <= s_noblock;
    else
      -- signal synchronization on the slow side (looking at fast signals)
      data_ready_sync_1 <= data_ready;
      data_ready_sync   <= data_ready_sync_1;
      drdy_o             <= data_ready_sync and not data_ready_block;
      if data_ready_sync = '1' then
        q_o <= fifo_out_data_fast;
      end if;

      case slow_state is
        when s_noblock =>
          if dack_i = '1' then 
            slow_state <= s_block;
            data_ready_block <= '1';
          end if;

        when s_block =>
          if data_ready_sync = '1' and data_ready_sync_1 = '0' then
            slow_state <= s_noblock;
            data_ready_block <= '0';
          end if;

      end case;

    end if;

  end process;

  
end architecture;