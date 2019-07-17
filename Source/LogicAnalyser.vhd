library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyser is
   port ( 
      reset          : in  std_logic;
      clock          : in  std_logic;

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

architecture Behavioral of LogicAnalyser is

signal currentSample     : SampleDataType;
signal lastSample        : SampleDataType;

begin

   Sampling_proc:
   process(reset, clock) 
   begin
      if rising_edge(clock) then
         if (reset = '1') then
            currentSample    <= (others => '0');
            lastSample       <= (others => '0');
         else
            currentSample    <= sample;
            lastSample       <= currentSample;
         end if;
      end if;
   end process;

	-- Instantiate the Unit Under Test (UUT)
   TriggerBlock_inst: 
   entity TriggerBlock 
      port map (
         clock          => clock,
         reset          => reset,
         enable         => enable,
         currentSample  => currentSample,
         lastSample     => lastSample,
         triggerFound   => triggerFound,
         
         -- Bus interface
         wr        => wr,       
         rd        => rd,
         addr      => addr,         
         dataIn    => dataIn,   
         dataOut   => dataOut
        );

end Behavioral;

