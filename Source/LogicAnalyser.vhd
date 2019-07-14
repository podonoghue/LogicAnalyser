library ieee;
use ieee.std_logic_1164.all;

use work.all;
use work.LogicAnalyserPackage.all;
 
library unisim;
use unisim.vcomponents.all;

entity LogicAnalyser is
   port ( 
      reset_n        : in  std_logic;
      clock_32MHz    : in  std_logic;
      
      -- Trigger logic
      enable         : in  std_logic;
      sample         : in  SampleDataType; -- Sample data
      trigger        : out std_logic;      -- Trigger output

      -- LUT serial configuration          
      lut_clock      : in  std_logic;  -- Used for LUT shift register          
      lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in  : in  std_logic;  -- Serial in for LUT shift register MSB first in
      lut_config_out : out std_logic   -- Serial out for LUT shift register
  );
end LogicAnalyser;
 
architecture Behavior of LogicAnalyser is 
 
signal reset         : std_logic;
signal clock         : std_logic;

signal currentSample : SampleDataType;
signal lastSample    : SampleDataType;

constant NUM_CHAINED_MODULES : positive := 2;
signal lut_chainIn     : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal lut_chainOut    : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);

begin
 
   Sampling_proc:
   process(reset, clock) 
   begin
      if (reset = '1') then
         currentSample <= (others => '0');
         lastSample    <= (others => '0');
      elsif rising_edge(clock) then
         currentSample <= sample;
         lastSample    <= currentSample;
      end if;
   end process;

   ConfigData_inst:
   entity ConfigData
      port map (
         reset          => reset,
         -- LUT serial configuration          
         lut_clock      => lut_clock,      -- Used for LUT shift register          
         lut_config_ce  => lut_config_ce,  -- Clock enable for LUT shift register
         lut_config_in  => lut_chainIn(1), -- Serial in for LUT shift register MSB first in
         lut_config_out => lut_chainOut(1) -- Serial out for LUT shift register
      );

	-- Instantiate the Unit Under Test (UUT)
   TriggerBlock_inst: 
   entity TriggerBlock 
      port map (
         reset            => reset,
         clock            => clock,
         enable           => enable,
         currentSample    => currentSample,
         lastSample       => lastSample,
         trigger          => trigger,
         -- LUT serial configuration          
         lut_clock      => lut_clock,      -- Used for LUT shift register          
         lut_config_ce  => lut_config_ce,  -- Clock enable for LUT shift register
         lut_config_in  => lut_chainIn(0), -- Serial in for LUT shift register MSB first in
         lut_config_out => lut_chainOut(0) -- Serial out for LUT shift register
        );

   SingleLutChainGenerate:
   if (NUM_CHAINED_MODULES = 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(0);
      lut_chainIn(0) <= lut_config_in;
   end generate;
   
   MutipleLutChainGenerate:
   if (NUM_CHAINED_MODULES > 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(lut_chainOut'left);
      lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   end generate;
   
   
   reset <= not reset_n;
   
   Digitalclockmanager_inst :
   entity work.DigitalClockManager
   port map   (
      -- Clock in ports
      clk_in1 => clock_32MHz,
      
      -- Clock out ports
      clk_out1 => clock
   );

end;
