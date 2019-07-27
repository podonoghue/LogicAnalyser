library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.logicanalyserpackage.all;

entity fifo_sdram_tb is
end entity;

architecture behavior of fifo_sdram_tb is

   signal   clock_100MHz   : std_logic := '0';
   signal   clock_100MHz_n : std_logic := '0';
   signal   reset          : std_logic := '0';

   signal   fifo_full      : std_logic;
   signal   fifo_wr_en     : std_logic      := '0';
   signal   fifo_data_in   : SampleDataType := (others => 'X');

   signal   sdram_clk      : std_logic;
   signal   sdram_cke      : std_logic;
   signal   sdram_cs_n     : std_logic;
   signal   sdram_ras_n    : std_logic;
   signal   sdram_cas_n    : std_logic;
   signal   sdram_we_n     : std_logic;
   signal   sdram_dqm      : std_logic_vector( 1 downto 0);
   signal   sdram_addr     : std_logic_vector(12 downto 0);
   signal   sdram_ba       : std_logic_vector( 1 downto 0);
   signal   sdram_data     : std_logic_vector(15 downto 0) := (others => 'Z');
   signal   initializing    : std_logic;

   -- clock_100MHz
   constant clock_period   : time    := 10 ns;
   signal   complete       : boolean := false;

begin

sdram_entity:
entity work.sdram
   port map (
      sdram_clk       => sdram_clk,
      sdram_cke       => sdram_cke,
      sdram_cs_n      => sdram_cs_n,
      sdram_ras_n     => sdram_ras_n,
      sdram_cas_n     => sdram_cas_n,
      sdram_we_n      => sdram_we_n,
      sdram_ba        => sdram_ba,
      sdram_dqm       => sdram_dqm,
      sdram_addr      => sdram_addr,
      sdram_data      => sdram_data
   );

fifo_sdram_uut:
entity work.FIFO_SDRAM
   port map (
      clock_100MHz    => clock_100MHz,
      clock_100MHz_n  => clock_100MHz_n,
      reset           => reset,

      fifo_full       => fifo_full,
      fifo_wr_en      => fifo_wr_en,
      fifo_data_in    => fifo_data_in,

      initializing      => initializing,

      sdram_clk       => sdram_clk,
      sdram_cke       => sdram_cke,
      sdram_cs_n      => sdram_cs_n,
      sdram_ras_n     => sdram_ras_n,
      sdram_cas_n     => sdram_cas_n,
      sdram_we_n      => sdram_we_n,
      sdram_ba        => sdram_ba,
      sdram_dqm       => sdram_dqm,
      sdram_addr      => sdram_addr,
      sdram_data      => sdram_data
   );

	-- instantiate the unit under test (uut)
   clock_100MHz_process :
   process
   begin
      while not complete loop
         clock_100MHz   <= '1';
         clock_100MHz_n <= '0';
         wait for clock_period/2;
         clock_100MHz   <= '0';
         clock_100MHz_n <= '1';
         wait for clock_period/2;
      end loop;
      -- kill clock_100MHz
      wait;
   end process;

   -- stimulus process
   StimProc:
   process

      variable writeCounter : SampleDataType := (others => '0');
      variable stuffRead    : SampleDataType := (others => 'Z');

      procedure writeStuff(count : natural) is
      begin
         for index in 0 to count-1 loop
            if (fifo_full = '1') then
               wait until fifo_full = '0';
               wait until falling_edge(clock_100MHz);
            end if;
            fifo_wr_en   <= '1';
            fifo_data_in <= std_logic_vector(writeCounter);
            wait until falling_edge(clock_100MHz);
            writeCounter := std_logic_vector(unsigned(writeCounter) + 1);
            fifo_wr_en <= '0';
         end loop;
         wait for 2* clock_period;
      end procedure;

   begin
      reset <= '1';
      wait for 2 * clock_period;
      reset <= '0';

      if (initializing = '1') then
         wait until (initializing = '0');
      end if;
      wait until falling_edge(clock_100MHz);
      wait for 0.5 ns;

      writeStuff(400000*32);
      --assert (fifo_full = '1');

      wait for 240 ns;
      complete <= true;

      wait;
   end process;

end;
