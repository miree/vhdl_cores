package uart_chipsim_pkg is

  procedure uart_chipsim_init(stop_unitl_connected : boolean);
  attribute foreign of uart_chipsim_init : procedure is "VHPIDIRECT uart_chipsim_init";

  -- if the function returns a positive integer, it is a valid value
  -- if the function returns a negative value it  is either
  --     TIMEOUT, meaning that nothing was read
  -- or  HANGUP, meaning that the client disconnected
  function uart_chipsim_read(timeout_value : integer) return integer;
  attribute foreign of uart_chipsim_read : function is "VHPIDIRECT uart_chipsim_read";

  procedure uart_chipsim_write(x : integer);
  attribute foreign of uart_chipsim_write : procedure is "VHPIDIRECT uart_chipsim_write";

  procedure uart_chipsim_flush;
  attribute foreign of uart_chipsim_flush : procedure is "VHPIDIRECT uart_chipsim_flush";


  shared variable my_var : integer := 43;

end package;

package body uart_chipsim_pkg is

  procedure uart_chipsim_init(stop_unitl_connected : boolean) is
  begin
    assert false report "VHPI" severity failure;
  end procedure;

  function uart_chipsim_read(timeout_value : integer) return integer is
  begin
    assert false report "VHPI" severity failure;
    return 0;
  end function;

  procedure uart_chipsim_write(x : integer) is
  begin
    assert false report "VHPI" severity failure;
  end procedure;

  procedure uart_chipsim_flush is
  begin
    assert false report "VHPI" severity failure;
  end procedure;

end package body;



library ieee;
use ieee.math_real.log2;
use ieee.math_real.ceil;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_chipsim_pkg.all;

entity uart_chipsim is
  generic (
    g_wait_until_connected      : boolean := true;
    g_continue_after_disconnect : boolean := true;
    g_baud_rate                 : integer := 9600
    );
  port (
    tx_o : out std_logic;
    rx_i :  in std_logic
  );
end entity;

architecture simulation of uart_chipsim is
  signal tx : std_logic := '1';
  signal clk_internal : std_logic := '1';
  constant clk_internal_period : time := 100 ms / g_baud_rate;
  signal value_from_file : integer := -1;
  signal tx_dat, rx_dat : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_stb, rx_stb : std_logic := '0';
  signal tx_stall : std_logic := '0';

  function fix_rx_dat(rx : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable result : std_logic_vector(rx'range) := rx;
  begin
    for i in result'range loop
      if result(i) /= '1' then
        result(i) := '0';
      end if;
    end loop;
    return result;
  end function;

begin

  -- clock generation
  clk_internal <= not clk_internal after clk_internal_period/2;

  -- instantiate a uart serializer
  uart_tx_inst: entity work.uart_tx 
    generic map (
      g_clk_freq => g_baud_rate*10,
      g_baud_rate => g_baud_rate,
      g_bits => 8)
    port map (
      clk_i   => clk_internal,
      dat_i   => tx_dat,
      stb_i   => tx_stb,
      stall_o => tx_stall,
      tx_o    => tx_o
      );

  uart_rx_inst: entity work.uart_rx
    generic map (
      g_clk_freq => g_baud_rate*10,
      g_baud_rate => g_baud_rate,
      g_bits => 8)
    port map (
      clk_i   => clk_internal,
      dat_o   => rx_dat,
      stb_o   => rx_stb,
      rx_i    => rx_i
      );


  main: process 
    variable client_connected : boolean;
    variable stop_until_client_connects : boolean := g_wait_until_connected;
  begin

    wait until rising_edge(clk_internal);

    while true loop

      uart_chipsim_init(stop_until_client_connects);
      stop_until_client_connects := not g_continue_after_disconnect;
      client_connected := true;

      while client_connected loop

        wait until rising_edge(clk_internal);

        -- get value from device
        if value_from_file < 0 then   
          value_from_file <= uart_chipsim_read(timeout_value=>0);
          if value_from_file = -2 then
            client_connected := false;
          end if;
        end if;

        -- provide value to simulation
        tx_stb <= '0';
        if value_from_file >= 0 and tx_stall = '0' then 
          tx_dat <= std_logic_vector(to_signed(value_from_file,8));
          tx_stb <= '1';
          value_from_file <= -1;
        end if;

        if rx_stb = '1' then 
          uart_chipsim_write(to_integer(unsigned(fix_rx_dat(rx_dat))));
          uart_chipsim_flush;
        end if;
      end loop;

    end loop;

  end process;

end architecture;
