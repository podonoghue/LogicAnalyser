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
--   Flags:       NUM_TRIGGER_FLAGS * MAX_TRIGGER_STEPS/16
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_PATTERNS=4, NUM_INPUTS=16)
--
-- Number of LUTs:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 = 16 * 4/2 * 16/2 = 256 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/4                = 16 * 4/4        =  16 LUTs
--   Flags:       NUM_TRIGGER_FLAGS * MAX_TRIGGER_STEPS/16                  =  2 * 16/16      =   2 LUT
-- TODO
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
-- |   Flag(1)   |   Flag(0)   |  Combiner   | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
-- |  LUT(274)   |  LUT(273)   |LUT(272..256)|LUT(255..240)|LUT(239..224)|            | LUT(31..16) |  LUT(15..0) |
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
--   See                                     |             |
--   StepFlags     +-------------------------+             |
--   and           |                                       |
--   Combiner      +-------------------+-------------------+
--                 |  PatternMatcher   |  PatternMatcher   |  See PatternMatcher
--                 |   LUT(255..248)   |   LUT(247..240)   |  for detailed mapping (8 LUTs)
--                 +-------------------+-------------------+
--
--==============================================================================================
entity TriggerBlock is
   port ( 
      clock          : in  std_logic;

      -- Bus interface
      wr_luts        : in   std_logic;
      dataIn         : in   DataBusType;

      rd_luts        : in   std_logic;
      dataOut        : out  DataBusType;
      
      bus_busy       : out  std_logic;
      
      -- Trigger logic
      enable         : in  std_logic;
      
      doSample       : in  std_logic;
      currentSample  : in  SampleDataType;  -- Current sample data
      lastSample     : in  SampleDataType;  -- Previous sample data
      
      triggerFound   : out std_logic        -- Trigger output

  );
end TriggerBlock;

architecture Structural of TriggerBlock is

signal triggerStep       : TriggerRangeType;
signal matchCount        : MatchCounterType;

-- Counter equal for current trigger step
signal triggerCountMatch    : std_logic;
signal triggerPatternMatch  : std_logic;

signal lut_chain : std_logic;

signal flags : std_logic_vector(NUM_TRIGGER_FLAGS-1 downto 0);

alias  contiguousTrigger : std_logic is flags(CONTIGUOUS_TRIGGER_INDEX);
alias  lastTriggerStep   : std_logic is flags(TRIGGER_SEQUENCE_COMPLETE_INDEX);

-- Number of modules chained together
constant NUM_CHAINED_MODULES : integer  := 3;
signal   lut_chainIn         : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal   lut_chainOut        : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);

-- LUT parallel to serial configuration          
signal lut_config_ce  : std_logic;  -- Clock enable for LUT shift register
signal lut_config_in  : std_logic;  -- Serial in for LUT shift register (MSB first)
signal lut_config_out : std_logic;  -- Serial out for LUT shift register

begin
   
   TriggerBusInterface_inst:
   entity work.TriggerBusInterface 
   PORT MAP(
      clock             => clock,
                        
      dataIn            => dataIn ,
      wr                => wr_luts,
                        
      dataOut           => dataOut,
      rd                => rd_luts,
                        
      busy              => bus_busy,
                        
      lut_config_ce     => lut_config_ce,
      lut_config_in     => lut_config_in,
      lut_config_out    => lut_config_out
   );

--   ConfigData_inst:
--   entity ConfigData
--      port map (
--         -- LUT serial configuration          
--         clock      => clock,      -- Used for LUT shift register          
--         lut_config_ce  => lut_config_ce,  -- Clock enable for LUT shift register
--         lut_config_in  => lut_chainIn(0), -- Serial in for LUT shift register MSB first in
--         lut_config_out => lut_chainOut(0) -- Serial out for LUT shift register
--      );
--
   PatternMatchers_inst:
   entity work.PatternMatchers
   port map ( 
      clock                => clock,               -- Used for pipelining
      doSample             => doSample,
      
      -- Trigger logic
      currentSample        => currentSample,       -- Current sample data
      lastSample           => lastSample,          -- Previous sample data
      triggerStep          => triggerStep,         -- Current step in trigger sequence
      triggerPatternMatch  => triggerPatternMatch, -- Pattern match output for current trigger step
      
      -- LUT serial configuration:
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS)/4 LUTs
      lut_config_ce        => lut_config_ce,       -- LUT shift-register clock enable
      lut_config_in        => lut_chainIn(2),      -- Serial configuration data input (MSB first)
      lut_config_out       => lut_chainOut(2)      -- Serial configuration data output
   );

   CountMatchers_inst:
   entity work.CountMatchers_sr
   port map ( 
      matchCounter       => matchCount,         -- Current match counter
      triggerStep        => triggerStep,        -- Current step in trigger sequence

      triggerCountMatch  => triggerCountMatch,  -- Trigger count comparator outputs

      -- LUT serial configuration:
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS)/4 LUTs
      clock          => clock,                  -- Used to clock LUT chain
      lut_config_ce  => lut_config_ce,          -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(1),         -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(1)         -- Serial configuration data output
   );

   StepFlags_inst:
   entity work.StepFlags
   generic map (
      NUM_FLAGS => NUM_TRIGGER_FLAGS
   )
   port map ( 
      -- Trigger logic
      triggerStep    => triggerStep,      -- Current step in trigger sequence
      flags          => flags,            -- Comparator outputs

      -- LUT serial configuration 
      -- MAX_TRIGGER_STEPS * NUM_MATCH_COUNTER_BITS/4 x 32 bits = MAX_TRIGGER_PATTERNS * NUM_INPUTS/2 LUTs
      clock          => clock,            -- Used to clock LUT chain
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(0),   -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(0)   -- Serial configuration data output
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
   
   TriggerStateMachine_inst:
   entity work.TriggerStateMachine 
   port map (
      clock                   => clock,
      enable                  => enable,
      
      doSample                => doSample,
      triggerCountMatch       => triggerCountMatch,
      triggerPatternMatch     => triggerPatternMatch,
      lastTriggerStep         => lastTriggerStep,
      contiguousTrigger       => contiguousTrigger,
      matchCount              => matchCount,
      triggerStep             => triggerStep,
      triggerFound            => triggerFound
   );

end Structural;

