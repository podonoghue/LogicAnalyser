library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyserWrapper is
   port ( 
      clock_50MHz    : in std_logic;
      
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

      -- SDRAM interface
      initializing   : out   std_logic;
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs_n     : out   std_logic;
      sdram_ras_n    : out   std_logic;
      sdram_cas_n    : out   std_logic;
      sdram_we_n     : out   std_logic;
      sdram_dqm      : out   std_logic_vector(1 downto 0);
      sdram_addr     : out   std_logic_vector(12 downto 0);
      sdram_ba       : out   std_logic_vector(1 downto 0);
      sdram_data     : inout std_logic_vector(15 downto 0);

      heartbeat      : out   std_logic
  );
end entity;
 
architecture Behavior of LogicAnalyserWrapper is 
 
signal clock_110MHz       : std_logic;
signal clock_110MHz_n     : std_logic;
signal clock_100MHz       : std_logic;

signal heartbeatFFs       : unsigned(24 downto 0);

begin
   heartbeat    <= heartbeatFFs(heartbeatFFs'left);
   heartbeatFFs <= (heartbeatFFs + 1) when rising_edge(clock_100MHz);

   LogicAnalyser_inst :
   entity work.LogicAnalyser
   port map ( 
      clock_110MHz   => clock_110MHz, 
      clock_110MHz_n => clock_110MHz_n, 
      clock_100MHz   => clock_100MHz, 
                      
      ft2232h_rxf_n  => ft2232h_rxf_n, 
      ft2232h_txe_n  => ft2232h_txe_n,      
      ft2232h_rd_n   => ft2232h_rd_n,      
      ft2232h_wr_n   => ft2232h_wr_n,    
      ft2232h_data   => ft2232h_data,  
      ft2232h_siwu_n => ft2232h_siwu_n,
      
      -- Trigger logic 
      sample         => sample,       
      armed_o        => armed,      
      sampleEnable_o => open,

      -- SDRAM Interface
      initializing => initializing,
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
      -- Clock in port
      clk_in1 => clock_50MHz,
      
      -- Clock out ports
      clk_out1 => clock_100MHz,
      clk_out2 => clock_110MHz,
      clk_out3 => clock_110MHz_n
   ); 

end;
