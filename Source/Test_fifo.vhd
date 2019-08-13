library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity Test_fifo is
   port ( 
      clock_50MHz    : in   std_logic;
      
      fifo_full      : out  std_logic;
      fifo_wr_en     : in   std_logic;
      fifo_data_in   : in   SampleDataType;
      
      fifo_not_empty : out  std_logic;
      fifo_rd_en     : in   std_logic;
      fifo_data_out  : out  SampleDataType;

      r_isEmpty      : out  std_logic;
      w_isFull       : out  std_logic;
      clk_out3       : out  std_logic
   );
end Test_fifo;

architecture Behavioral of Test_fifo is

signal clock_110MHz       : std_logic;
signal clock_110MHz_n     : std_logic;
signal clock_100MHz       : std_logic;

begin

   -- Sampled data -> SDRAM
	write_fifo_inst:
   entity work.fifo_2clock 
   port map(
      -- 100 MHz clock domain
      w_clock        => clock_100MHz,
		w_clear        => '0',      
		w_enable       => fifo_wr_en,
		w_isFull       => open,
		w_data         => fifo_data_in,

      -- 110 MHz clock domain
      r_clock        => clock_110MHz,
		r_clear        => '0',      
		r_isEmpty      => r_isEmpty,
		r_enable       => fifo_rd_en,		
      r_data         => fifo_data_out
	);

   
   --================================================
   
   Digitalclockmanager_inst :
   entity work.DigitalClockManager
   port map   (
      -- Clock in port
      clk_in1 => clock_50MHz,
      
      -- Clock out ports
      clk_out1 => clock_100MHz,
      clk_out2 => clock_110MHz,
      clk_out3 => clock_110MHz_n
   ); 

end Behavioral;

