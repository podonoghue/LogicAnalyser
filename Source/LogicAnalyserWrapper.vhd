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
      wr             : in   std_logic;
      rd             : in   std_logic;
      addr           : in   AddressBusType;
      dataIn         : in   DataBusType;
      dataOut        : out  DataBusType;
      
      -- Trigger logic
      enable         : in  std_logic;
      sample         : in  SampleDataType; -- Sample data
      triggerFound   : out std_logic       -- Trigger output

  );
end entity;
 
architecture Behavior of LogicAnalyserWrapper is 
 
signal reset         : std_logic;
signal clock_200MHz  : std_logic;
signal sampleFF      : SampleDataType;
signal wrFF          : std_logic;
signal rdFF          : std_logic;
signal addrFF        : AddressBusType;
signal dataInFF      : DataBusType;
signal enableFF      : std_logic;

begin
--   SampleSync_inst:
--   entity work.Synchronizer
--   Generic Map (
--      width => SampleDataType'length
--   )
--   Port Map ( 
--      clock     => clock_200MHz,
--      reset     => reset,
--      inputs    => sample,
--      outputs   => sampleFF
--   );

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
            wrFF      <= wr;
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
      clock          => clock_200MHz, 
                      
      -- Bus interface 
      wr             => wrFF,      
      rd             => rdFF,      
      addr           => addrFF,    
      dataIn         => dataInFF,  
      dataOut        => dataOut, 
                      
      -- Trigger logic 
      enable         => enableFF,      
      sample         => sampleFF,       
      triggerFound   => triggerFound 
  );
   
   --================================================
   
   Digitalclockmanager_inst :
   entity work.DigitalClockManager
   port map   (
      -- Clock in ports
      clk_in1 => clock_32MHz,
      
      -- Clock out ports
      clk_out1 => clock_200MHz
   ); 

end;
