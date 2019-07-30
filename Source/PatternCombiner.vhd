library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

--=================================================================================
-- Implements MAX_TRIGGER_STEPS logical operations on MAX_TRIGGER_PATTERNS-wide inputs
-- i.e. MTS x MC -> MTS outputs
--
-- MAX_TRIGGER_PATTERNS must be 2 or 4
-- The logical operation value is encoded in the LUT
--
-- LUT serial configuration:
-- MAX_TRIGGER_STEP LUTs
--
-- Each LUT implements one up to 4 bit-wide logic function to combine the patterns matchers.
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_PATTERNS=2)
-- 
-- Number of LUTs = MAX_TRIGGER_STEPS = 16 LUTs
--
-- +-------------+-------------+------------+-------------+-------------+
-- | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |
-- +-------------+-------------+------------+-------------+-------------+
-- |           LUT(7)          | ...    ... |           LUT(0)          |
-- +-------------+-------------+------------+-------------+-------------+
-- |             |
-- |             +-------------------------------------------------+
-- |                                                               |
-- |              Mapping for a typical LUT                        |
-- +---------------------------------------------------------------+
-- |3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                    | 
-- |1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0| <- LUT bit #
-- +---------------+---------------+---------------+---------------+
-- |                          TRIGGER 15                           | <- Single triggers
-- +---------------+---------------+---------------+---------------+
-- |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0| CMP   | <- Comparators in trigger
-- +---------------+---------------+---------------+---------------+
-- The CFGLUT5 are treated as 2 x LUT4s. 
-- One LUT4 handles 2 comparators from one trigger, the other LUT4 is unused
--
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_PATTERNS=4)
-- 
-- Number of LUTs = MAX_TRIGGER_STEPS = 16 LUTs
--
-- +-------------+-------------+------------+-------------+-------------+
-- | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |
-- +-------------+-------------+------------+-------------+-------------+
-- |   LUT(15)   |   LUT(14)   | ...    ... |   LUT(1)    |   LUT(0)    |
-- +-------------+-------------+------------+-------------+-------------+
-- |             |
-- |             +-------------------------------------------------+
-- |                                                               |
-- |              Mapping for a typical LUT                        |
-- +---------------------------------------------------------------+
-- |3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                    | 
-- |1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0| <- LUT bit #
-- +---------------+---------------+---------------+---------------+
-- |                           TRIGGER 15                          | <- Single triggers
-- +---------------+---------------+---------------+---------------+
-- | 000000000000000000000000000000|          COMP[3..0]           | <- Comparators in trigger
-- +---------------+---------------+---------------+---------------+
-- The CFGLUT5 are treated as 2 x LUT4s. 
-- One LUT4 handles 4 comparators from one trigger, the other LUT4 is unused
--
--=================================================================================
entity PatternCombiner is
    port ( 
         -- All pattern match values across all steps
         conditions     : in  TriggerConditionArray; 
         
         -- Trigger outputs for each step
         triggers       : out std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0); 
         
         -- LUT serial configuration: MAX_TRIGGER_STEPS*MAX_TRIGGER_PATTERNS)/4 LUTs
         lut_clock      : in  std_logic;  -- Used to clock LUT chain
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end entity;

architecture behavioral of PatternCombiner is

-- Each LUT can implement a combiner for a step
constant NUM_LUTS    : integer := MAX_TRIGGER_STEPS;

signal lut_chainIn   : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainOut  : std_logic_vector(NUM_LUTS-1 downto 0);

begin

   GenerateLogic2:
   if (MAX_TRIGGER_PATTERNS = 2) generate
   begin
      GenerateLogicBlock2: 
      for index in NUM_LUTS-1 downto 0 generate
      begin
         cfglut5_inst : CFGLUT5           -- For simulation  cfglut5_inst : entity CFGLUT5
         generic map (
            init => x"00000000"
         )
         port map (
            -- Reconfigure shift register
            clk => lut_clock,             -- LUT shift-register clock
            ce  => lut_config_ce,         -- LUT shift-register clock enable
            cdi => lut_chainIn(index),    -- Serial configuration data input (MSB first)
            cdo => lut_chainOut(index),   -- Serial configuration data output
            
            -- Logic function inputs
            i4  => '0',                   -- Not used
            i3  => '0',                   -- Not used
            i2  => '0',                   -- Not used
            i1  => conditions(index)(1),  -- Logic data input
            i0  => conditions(index)(0),  -- Logic data input
            
            o5  => triggers(index),       -- 4-LUT output
            o6  => open                   -- unused     
         );
      end generate;

   end generate;
         
   GenerateLogic4:
   if (MAX_TRIGGER_PATTERNS = 4) generate
   begin
      GenerateLogicBlock4: 
      for index in NUM_LUTS-1 downto 0 generate
      begin
         cfglut5_inst : CFGLUT5           -- For simulation  cfglut5_inst : entity CFGLUT5
         generic map (
            init => x"00000000"
         )
         port map (
            -- Reconfigure shift register
            clk => lut_clock,             -- LUT shift-register clock
            ce  => lut_config_ce,         -- LUT shift-register clock enable
            cdi => lut_chainIn(index),    -- Serial configuration data input (MSB first)
            cdo => lut_chainOut(index),   -- Serial configuration data output
            
            -- Logic function inputs
            i4  => '0',                   -- Not used
            i3  => conditions(index)(3),  -- Logic data input
            i2  => conditions(index)(2),  -- Logic data input
            i1  => conditions(index)(1),  -- Logic data input
            i0  => conditions(index)(0),  -- Logic data input
            
            o5  => triggers(index),       -- 4-LUT output
            o6  => open                   -- unused     
         );
      end generate;
   end generate;
         
   -- Chain LUT config data shift registers
   lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   lut_config_out <= lut_chainOut(lut_chainOut'left);

end Behavioral;
