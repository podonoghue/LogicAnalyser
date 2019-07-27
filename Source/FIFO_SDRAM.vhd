library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

use work.all;
use work.LogicAnalyserPackage.all;

entity FIFO_SDRAM is
   port ( 
      clock_100MHz    : in   std_logic;
      clock_100MHz_n  : in   std_logic;
      reset           : in   std_logic;
      
      fifo_full       : out  std_logic;
      fifo_wr_en      : in   std_logic;
      fifo_data_in    : in   SampleDataType;
      
      -- SDRAM interface
      initializing    : out   std_logic;
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs_n     : out   std_logic;
      sdram_ras_n    : out   std_logic;
      sdram_cas_n    : out   std_logic;
      sdram_we_n     : out   std_logic;
      sdram_ba       : out   std_logic_vector( 1 downto 0);
      sdram_dqm      : out   std_logic_vector( 1 downto 0);
      sdram_addr     : out   std_logic_vector(12 downto 0);
      sdram_data     : inout std_logic_vector(15 downto 0)
   );
end FIFO_SDRAM;

architecture Behavioral of FIFO_SDRAM is

signal fifo_empty     : std_logic;
signal fifo_rd_en     : std_logic;
signal fifonotempty   : std_logic;
signal fifo_data_out  : SampleDataType;

signal sdramAddress   : sdram_AddrType; 

begin

	Fifo_inst:
   entity work.fifo 
   port map(
		clock          => clock_100MHz,
		reset          => reset,
      
		fifo_full      => fifo_full,
		fifo_wr_en     => fifo_wr_en,
		fifo_data_in   => fifo_data_in,

		fifo_empty     => fifo_empty,
		fifo_rd_en     => fifo_rd_en,		
      fifo_data_out  => fifo_data_out
	);

   fifoNotEmpty      <= not fifo_empty;

   process (clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         if (reset = '1') then
            sdramAddress <= x"fffff0";
         elsif (fifo_rd_en = '1') then
            sdramAddress <= std_logic_vector(unsigned(sdramAddress) + 1);
         end if;
      end if;
   end process;
   
   SDRAM_Controller_inst :
   entity work.SDRAM_Controller
   port map(
      clock_100MHz     => clock_100MHz,
      clock_100MHz_n   => clock_100MHz_n,
      reset            => reset,

      cmd_wr           => fifoNotEmpty,
      cmd_rd           => '0',
      cmd_address      => sdramAddress,
      cmd_dataIn       => fifo_data_out,

      cmd_wr_accepted  => fifo_rd_en,
      cmd_done         => open,
      cmd_dataOut      => open,
      cmd_dataOutReady => open,
      
      initializing     => initializing,
      
      sdram_clk        => sdram_clk,
      sdram_cke        => sdram_cke,
      sdram_cs_n       => sdram_cs_n,
      sdram_ras_n      => sdram_ras_n,
      sdram_cas_n      => sdram_cas_n,
      sdram_we_n       => sdram_we_n,
      sdram_dqm        => sdram_dqm,
      sdram_ba         => sdram_ba,
      sdram_addr       => sdram_addr,
      sdram_data       => sdram_data
   );

end Behavioral;

