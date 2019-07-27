library ieee;
use ieee.std_logic_1164.all;
 
library unisim;
use unisim.vcomponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyserWrapper is
   port ( 
      reset_n        : in    std_logic;
      clock_32MHz    : in    std_logic;

      -- Bus interface
      ft2232h_rxf_n  : in    std_logic;      -- Rx FIFO Full
      ft2232h_rd_n   : out   std_logic;      -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_txe_n  : in    std_logic;      -- Tx FIFO Empty 
      ft2232h_wr_n   : out   std_logic;      -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data   : inOut DataBusType;    -- FIFO Data I/O
      ft2232h_siwu_n : out   std_logic;      -- Flush USB buffer(Send Immediate / WakeUp signal)
      
      -- Trigger logic
      sample         : in    SampleDataType;
      armed          : out   std_logic;
      sampling       : out   std_logic;

      -- SDRAM interface
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs_n     : out   std_logic;
      sdram_ras_n    : out   std_logic;
      sdram_cas_n    : out   std_logic;
      sdram_we_n     : out   std_logic;
      sdram_dqm      : out   std_logic_vector(1 downto 0);
      sdram_addr     : out   std_logic_vector(12 downto 0);
      sdram_ba       : out   std_logic_vector(1 downto 0);
      sdram_data     : inout std_logic_vector(15 downto 0)     
  );
end entity;
 
architecture Behavior of LogicAnalyserWrapper is 
 
signal reset              : std_logic;
signal clock_100MHz       : std_logic;
signal clock_100MHz_n     : std_logic;
signal clock_200MHz       : std_logic;

signal sampleFF           : SampleDataType;

begin
   reset <= not reset_n when rising_edge(clock_100MHz);
   
   LogicAnalyser_inst :
   entity work.LogicAnalyser
   port map ( 
      reset          => reset, 
      clock_100MHz   => clock_100MHz, 
      clock_100MHz_n => clock_100MHz_n, 
      clock_200MHz   => clock_200MHz, 
                      
      ft2232h_rxf_n  => ft2232h_rxf_n, 
      ft2232h_txe_n  => ft2232h_txe_n,      
      ft2232h_rd_n   => ft2232h_rd_n,      
      ft2232h_wr_n   => ft2232h_wr_n,    
      ft2232h_data   => ft2232h_data,  
      ft2232h_siwu_n => ft2232h_siwu_n,
      
      -- Trigger logic 
      sample         => sample,       
      armed          => armed,      
      sampling       => sampling,
      
      -- SDRAM Interface
      sdram_clk    => sdram_clk,   
      sdram_cke    => sdram_cke, 
      sdram_cs_n   => sdram_cs_n,    
      sdram_ras_n  => sdram_ras_n,   
      sdram_cas_n  => sdram_cas_n,   
      sdram_we_n   => sdram_we_n,    
      sdram_dqm    => sdram_dqm,   
      sdram_addr   => sdram_addr,  
      sdram_ba     => sdram_ba, 
      sdram_data   => sdram_data
 );
   
   --================================================
   
   Digitalclockmanager_inst :
   entity work.DigitalClockManager
   port map   (
      -- Clock in ports
      clk_in1 => clock_32MHz,
      
      -- Clock out ports
      clk_out1 => clock_200MHz,
      clk_out2 => clock_100MHz,
      clk_out3 => clock_100MHz_n,
      
      locked   => open
   ); 

end;
