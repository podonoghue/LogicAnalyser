library ieee;
use ieee.std_logic_1164.all;
 
library unisim;
use unisim.vcomponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyserWrapper is
   port ( 
      reset_n        : in  std_logic;
      clock_32MHz    : in  std_logic;

      -- Bus interface
      ft2232h_rxf_n  : in   std_logic;      -- Rx FIFO Full
      ft2232h_txe_n  : in   std_logic;      -- Tx FIFO Empty 
      ft2232h_rd_n   : out  std_logic;      -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_wr     : out  std_logic;      -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data   : inOut DataBusType; -- FIFO Data I/O
      
      -- Trigger logic
      enable         : in  std_logic;
      sample         : in  SampleDataType; -- Sample data
      triggerFound   : out std_logic;      -- Trigger output

      -- SDRAM interface
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs       : out   std_logic;
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
 
signal reset          : std_logic;
signal clock_100MHz   : std_logic;
signal clock_100MHz_n : std_logic;
signal clock_200MHz   : std_logic;
signal sampleFF       : SampleDataType;
signal wrFF           : std_logic;
signal rdFF           : std_logic;
signal addrFF         : AddressBusType;
signal dataInFF       : DataBusType;
signal enableFF       : std_logic;

attribute IOB : string;
attribute IOB of sampleFF : signal is "true"; 
attribute IOB of wrFF     : signal is "true"; 
attribute IOB of rdFF     : signal is "true"; 
attribute IOB of addrFF   : signal is "true"; 
attribute IOB of dataInFF : signal is "true"; 
attribute IOB of enableFF : signal is "true"; 

-- Xilinx placement pragmas:
--synthesis attribute IOB of command_q is "TRUE"
--synthesis attribute IOB of addr_q is "TRUE"
--synthesis attribute IOB of dqm_q is "TRUE"
--synthesis attribute IOB of cke_q is "TRUE"
--synthesis attribute IOB of bank_q is "TRUE"
--synthesis attribute IOB of data_q is "TRUE"

-- 3-state SDRAM data bus
--signal sdram_data_o   : std_logic_vector(15 downto 0);
--signal sdram_data_t   : std_logic;
--signal sdram_data_i   : std_logic_vector(15 downto 0);

begin

--   sdram_data   <= sdram_data_o when sdram_data_t = '1' else (others => 'Z');
--   sdram_data_i <= sdram_data;
   
   SampleSyncProc:
   process(clock_200MHz) 
   begin
      if rising_edge(clock_200MHz) then
         reset <= not reset_n;
         if (reset = '1') then
            sampleFF <= (others => '0');
            wrFF      <= '0';
            rdFF      <= '0';
            addrFF    <= (others => '0');
            dataInFF  <= (others => '0');
            enableFF  <= '0';
         else
            sampleFF <= sample;
            wrFF      <= ft2232h_wr;
            rdFF      <= rd;
            addrFF    <= addr;
            dataInFF  <= dataIn;
            enableFF  <= enable;
         end if;
      end if;
   end process;
   
   LogicAnalyser_inst :
   entity work.LogicAnalyser
   port map ( 
      reset          => reset, 
      clock_100MHz   => clock_100MHz, 
      clock_100MHz_n => clock_100MHz_n, 
      clock_200MHz   => clock_200MHz, 
                      
      -- Bus interface 
      ft2232h_wr             => wrFF,      
      rd             => rdFF,      
      addr           => addrFF,    
      dataIn         => dataInFF,  
      dataOut        => dataOut, 
                      
      -- Trigger logic 
      enable         => enableFF,      
      sample         => sampleFF,       
      triggerFound   => triggerFound,
      
      -- SDRAM Interface
      sdram_clk    => sdram_clk,   
      sdram_cke    => sdram_cke, 
      sdram_cs     => sdram_cs,    
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
