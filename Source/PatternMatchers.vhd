library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

--==============================================================================================
-- Implements MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS of NUM_INPUTS-wide trigger circuits supporting 
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
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS)/4 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_PATTERNS=4, NUM_INPUTS=16)
--
-- Number of LUTs:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 = 16 * 4/2 * 16/2 = 256 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/4                = 16 * 4/4        =  16 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16                    =  2 * 16/16      =   2 LUT
--
-- +-------------+-------------+------------+-------------+-------------+-------------+
-- | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |  Combiner   |
-- +-------------+-------------+------------+-------------+-------------+-------------+
-- |LUT(272..256)|LUT(255..240)|            | LUT(47..12) | LUT(31..16) |  LUT(15..0) |
-- +-------------+-------------+------------+-------------+-------------+-------------+
--               |             |                                          See          
--   +-----------+             +-------------+                            Combiner     
--   |                                       |                                         
--   +-------------------+-------------------+                                         
--   |  PatternMatcher   |  PatternMatcher   |  See PatternMatcher                               
--   |   LUT(239..232)   |   LUT(231..224)   |  for detailed mapping                     
--   +-------------------+-------------------+  (8 LUTs)                            
--
--==============================================================================================
entity PatternMatchers is
   port ( 
      clock                : in  std_logic;
      doSample             : in  std_logic;

      -- Sample values
      currentSample        : in  SampleDataType;    -- Current sample data
      lastSample           : in  SampleDataType;    -- Previous sample data
      
      -- Which step in trigger sequence
      triggerStep          : in  TriggerRangeType;

      -- Pattern match output for current trigger step
      triggerPatternMatch  : out std_logic; 
                                 
      -- LUT serial configuration 
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS*MAX_TRIGGER_PATTERNS/4 LUTs
      --   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
      lut_clock            : in  std_logic;  -- Used to clock LUT chain
      lut_config_ce        : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in        : in  std_logic;  -- Serial in for LUT shift register (MSB first)
      lut_config_out       : out std_logic   -- Serial out for LUT shift register
   );
end PatternMatchers;

architecture Behavioral of PatternMatchers is

constant COMPARATORS_PER_BLOCK : positive := 2;
constant NUM_TRIGGER_BLOCKS    : positive := MAX_TRIGGER_PATTERNS/COMPARATORS_PER_BLOCK;

-- Trigger outputs for each step 
signal triggers                : std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0);
signal triggerFFs              : std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0);

-- All pattern match values across all steps
signal conditions              : TriggerConditionArray;
signal conditionFFs            : TriggerConditionArray;

-- Number of modules chained together
constant NUM_CHAINED_MODULES   : integer := MAX_TRIGGER_STEPS*NUM_TRIGGER_BLOCKS+1;
signal   lut_chainIn           : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal   lut_chainOut          : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);

begin
   
   GenerateSteps: -- Each trigger step
   for triggerStep in MAX_TRIGGER_STEPS-1 downto 0 generate
   
   begin
   
      GenerateComparisons: -- Each LUT for comparator in trigger step
      for index in NUM_TRIGGER_BLOCKS-1 downto 0 generate
      
      -- Index into LUT chain
      constant lut_config_index : integer := triggerStep*NUM_TRIGGER_BLOCKS+index+1;

      begin
         
         PatternMatcher_inst : entity work.PatternMatcher
         port map (            
            -- Logic function
            currentSample  => currentSample,       -- Current sample data
            lastSample     => lastSample,          -- Prevous sample data
            
            trigger1       => conditions(triggerStep)(COMPARATORS_PER_BLOCK*index+1),  -- Comparison output
            trigger0       => conditions(triggerStep)(COMPARATORS_PER_BLOCK*index),    -- Comparison output

            -- LUT serial configuration (NUM_INPUTS/2 LUTs)
            lut_clock      => lut_clock,                      -- Used to clock LUT chain
            lut_config_ce  => lut_config_ce,                  -- Clock enable for LUT shift register
            lut_config_in  => lut_chainIn(lut_config_index),  -- Serial in for LUT shift register (MSB first)
            lut_config_out => lut_chainOut(lut_config_index)  -- Serial out for LUT shift register
         );
      end generate;   
   end generate;
 
   -- Pipeline the triggers values before combining them
   conditionFFs <= conditions when rising_edge(clock) and (doSample = '1');
   
   PatternCombiner_inst:
   entity work.PatternCombiner
   port map ( 
      -- Trigger logic
      conditions     => conditionFFs,     -- All pattern match values across all steps
      
      triggers       => triggers,         -- Trigger outputs for each step 
                                     
      -- LUT serial configuration (MAX_TRIGGER_STEPS*MAX_TRIGGER_PATTERNS)/4 LUTs)
      lut_clock      => lut_clock,        -- Used to clock LUT chain
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(0),   -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(0)   -- Serial configuration data output
   );

   -- Pipeline values
   triggerFFs          <= triggers when rising_edge(clock) and (doSample = '1');
   
   triggerPatternMatch <= triggerFFs(to_integer(triggerStep));   

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
      
end Behavioral;

