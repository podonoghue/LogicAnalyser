library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

--=================================================================================
-- Implements MAX_TRIGGER_STEPS of MATCH_COUNTER_BITS-wide fixed value comparators
-- The comparison value is encoded in the LUT
--=================================================================================
entity CountMatches is
    port ( 
         -- Trigger logic
         count        : in  MatchCounterType;  -- Current match counter value
         triggerStep  : in  TriggerRangeType;  -- Current match counter value

         equal        : out std_logic;         -- Counter equal for current trigger step

         -- LUT serial configuration: MAX_TRIGGER_STEPS/2 * MATCH_COUNTER_BITS/4 LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end CountMatches;

architecture Behavioral of CountMatches is

constant COMPARATORS_PER_BLOCK : positive := 2;
constant NUM_COMPARATOR_BLOCKS : positive := MAX_TRIGGER_STEPS/COMPARATORS_PER_BLOCK;

signal chainIn     : std_logic_vector(NUM_COMPARATOR_BLOCKS-1 downto 0);
signal chainOut    : std_logic_vector(NUM_COMPARATOR_BLOCKS-1 downto 0);

signal equals      : std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0);  

begin
   
   equal <= equals(triggerStep);

   GenerateTriggers: 
   for index in NUM_COMPARATOR_BLOCKS-1 downto 0 generate
      CountMatcherPair_inst : entity work.CountMatcherPair
      port map (
         -- Logic function
         count   => count,                                -- Current counter value
         equalA  => equals(COMPARATORS_PER_BLOCK*index+1), -- Comparison output
         equalB  => equals(COMPARATORS_PER_BLOCK*index),   -- Comparison output

         -- LUT serial configuration 
         lut_clock      => lut_clock,       -- Used for LUT shift register          
         lut_config_ce  => lut_config_ce,   -- Clock enable for LUT shift register
         lut_config_in  => chainIn(index),  -- Serial in for LUT shift register (MSB first)
         lut_config_out => chainOut(index)  -- Serial out for LUT shift register
      );
   end generate;
   
   GenerateLogicSimple:
   if (NUM_COMPARATOR_BLOCKS = 1) generate
      chainIn(0)     <= lut_config_in;
      lut_config_out <= chainOut(0);
   end generate;
   
   GenerateLogicComplex:
   if (NUM_COMPARATOR_BLOCKS > 1) generate
      chainIn        <= chainOut(chainOut'left-1 downto 0) & lut_config_in;
      lut_config_out <= chainOut(chainOut'left);
   end generate;
   
end Behavioral;

