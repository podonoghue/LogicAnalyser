library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

--==============================================================================================
-- Implements MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS of NUM_INPUTS-wide trigger circuits supporting 
--
--    High    Low     Rising     Falling     Change
--    -----              +---   ---+        ---+ +---
--                      /           \           X
--           -----  ---+             +---   ---+ +---
-- The trigger condition is encoded in the LUT.
--
-- The current trigger is selected by triggerStep.
--
-- LUT serial configuration:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS)/4 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_CONDITIONS=4, NUM_INPUTS=16)
--
-- Number of LUTs:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 = 16 * 4/2 * 16/2 = 256 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/4                = 16 * 4/4        =  16 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16                    =  2 * 16/16      =   2 LUT
--
-- +-------------+-------------+-------------+------------+-------------+-------------+
-- |  Combiner   | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |
-- +-------------+-------------+-------------+------------+-------------+-------------+
-- |LUT(272..256)|LUT(255..240)|LUT(239..224)|            | LUT(31..16) |  LUT(15..0) |
-- +-------------+-------------+-------------+------------+-------------+-------------+
--   See                       |             |
--   Combiner      +-----------+             +-------------+
--                 |                                       |
--                 +-------------------+-------------------+
--                 |  TriggerMatcher   |  TriggerMatcher   |  See TriggerMatcher
--                 |   LUT(239..232)   |   LUT(231..224)   |  for detailed mapping (8 LUTs)
--                 +-------------------+-------------------+
--
--==============================================================================================
entity TriggerMatches is
    port ( 
         -- Trigger logic
         currentSample : in  SampleDataType;    -- Current sample data
         lastSample    : in  SampleDataType;    -- Previous sample data
         triggerStep   : in  TriggerRangeType;  -- Current match counter value

         trigger       : out std_logic;         -- Trigger output for current trigger step
                                    
         -- LUT serial configuration 
         --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 LUTs
         --   Combiner:    MAX_TRIGGER_STEPS*MAX_TRIGGER_CONDITIONS/4 LUTs
         --   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end TriggerMatches;

architecture Behavioral of TriggerMatches is

constant COMPARATORS_PER_BLOCK : positive := 2;
constant NUM_TRIGGER_BLOCKS    : positive := MAX_TRIGGER_CONDITIONS/COMPARATORS_PER_BLOCK;

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
                                     
      -- LUT serial configuration (MAX_TRIGGER_STEPS*MAX_TRIGGER_CONDITIONS)/4 LUTs)
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
            
            trigger1      => conditions(triggerStep)(COMPARATORS_PER_BLOCK*index+1),  -- Comparison output
            trigger0      => conditions(triggerStep)(COMPARATORS_PER_BLOCK*index),    -- Comparison output

            -- LUT serial configuration (NUM_INPUTS/2 LUTs)
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

