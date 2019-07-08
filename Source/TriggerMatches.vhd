library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

--==============================================================================================
-- Implements MAX_TRIGGER_STEPS * MAX_CONDITIONS of NUM_INPUTS-wide trigger circuits supporting 
--
--    High    Low     Rising     Falling     Change
--    -----              +---   ---+        ---+ +---
--                      /           \           X
--           -----  ---+             +---   ---+ +---
-- The trigger condition is encoded in the LUT.
--
-- The current trigger is selected by triggerStep.
--==============================================================================================
entity TriggerMatches is
    port ( 
         -- Trigger logic
         currentSample : in  SampleDataType;    -- Current sample data
         lastSample    : in  SampleDataType;    -- Previous sample data
         triggerStep   : in  TriggerRangeType;  -- Current match counter value

         trigger       : out std_logic;         -- Trigger output for current trigger step
                                    
         -- LUT serial configuration 
         -- MAX_TRIGGER_STEPS * MAX_CONDITIONS of NUM_INPUTS/2 LUTs
         -- => MAX_TRIGGER_STEPS * MAX_CONDITIONS of NUM_INPUTS/2 x 32 bits config data 
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end TriggerMatches;

architecture Behavioral of TriggerMatches is

constant TRIGGERS_PER_BLOCK : positive := 2;
constant NUM_TRIGGER_BLOCKS : positive := MAX_CONDITIONS/TRIGGERS_PER_BLOCK;

signal chainIn     : std_logic_vector(MAX_TRIGGER_STEPS*NUM_TRIGGER_BLOCKS-1 downto 0);
signal chainOut    : std_logic_vector(MAX_TRIGGER_STEPS*NUM_TRIGGER_BLOCKS-1 downto 0);
signal lut_chain   : std_logic;

signal triggers    : std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0);

-- Trigger logic
signal conditions : TriggerConditionArray;

begin
   
   trigger <= triggers(triggerStep);
   
   Combiner_inst:
   entity work.Combiner
   port map ( 
      -- Trigger logic
      conditions     => conditions,       -- Current sample data
      triggers       => triggers,         -- Previous sample data
                                     
      -- LUT serial configuration 
      lut_clock      => lut_clock,        -- LUT shift-register clock
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chain,        -- Serial configuration data input (MSB first)
      lut_config_out => lut_config_out    -- Serial configuration data output
   );

   GenerateComparisons: -- Each trigger step
   for triggerStep in MAX_TRIGGER_STEPS-1 downto 0 generate
   
   begin
   
      GenerateTriggers: -- Each LUT for comparator in trigger step
      for index in NUM_TRIGGER_BLOCKS-1 downto 0 generate

      constant lut_config_index : integer := triggerStep*NUM_TRIGGER_BLOCKS+index;

      begin
         
         TriggerMatcher_inst : entity work.TriggerMatcher

         port map (
            -- Logic function
            currentSample => currentSample,       -- Current sample data
            lastSample    => lastSample,          -- Prevous sample data
            
            triggerA      => conditions(triggerStep)(TRIGGERS_PER_BLOCK*index+1),  -- Comparison output
            triggerB      => conditions(triggerStep)(TRIGGERS_PER_BLOCK*index),    -- Comparison output

            -- LUT serial configuration 
            lut_clock      => lut_clock,                  -- Used for LUT shift register          
            lut_config_ce  => lut_config_ce,              -- Clock enable for LUT shift register
            lut_config_in  => chainIn(lut_config_index),  -- Serial in for LUT shift register (MSB first)
            lut_config_out => chainOut(lut_config_index)  -- Serial out for LUT shift register
         );
      end generate;   
   end generate;

   -- Wire together the LUT configuration shift registers into a single chain
   
   GenerateLogicSimple:
   if (MAX_TRIGGER_STEPS*NUM_TRIGGER_BLOCKS = 1) generate
      chainIn(0)     <= lut_config_in;
      lut_chain      <= chainOut(0);
   end generate;
   
   GenerateLogicComplex:
   if (MAX_TRIGGER_STEPS*NUM_TRIGGER_BLOCKS > 1) generate
      chainIn        <= chainOut(chainOut'left-1 downto 0) & lut_config_in;
      lut_chain      <= chainOut(chainOut'left);
   end generate;
      
end Behavioral;

