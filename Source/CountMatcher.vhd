library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

--=================================================================
-- Implements 2 of MATCH_COUNTER_BITS-wide fixed value comparators
-- The comparison value is encoded in the LUT
-- 
-- Each LUT implement 4-bots of the countercomparator
--
-- Example MATCH_COUNTER_BITS=16
-- MATCH_COUNTER_BITS/4 LUTs
--
-- +-----------+-----------+-----------+-----------+
-- |  LUT(3)   |  LUT(2)   |  LUT(1)   |  LUT(0)   |
-- +-----------+-----------+-----------+-----------+
-- |          16-bit counter match value           |
-- +-----------+-----------+-----------+-----------+
-- |                                               |
-- +                                               +---------------+
-- |                                                               |
-- |             Mapping for a typical LUT                         |
-- +---------------------------------------------------------------+
-- |3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                    | 
-- |1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0| <- LUT bit #
-- +---------------+---------------+---------------+---------------+
-- The CFGLUT5 are treated as LUT4. Each LUT4 matches 4 counter bits
--
--========================================================================
entity CountMatcherPair is
    port ( 
         -- Trigger logic
         count      : in  MatchCounterType; -- Current match counter value
         equal1     : out std_logic;        -- Comparator output 1 LUT[15..8]
         equal0     : out std_logic;        -- Comparator output 0 LUT[7..0]

         -- LUT serial configuration: MATCH_COUNTER_BITS/4 LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end CountMatcherPair;

architecture behavioral of CountMatcherPair is

-- Each LUT implements a 4-bits of the comparator   
constant BITS_PER_LUT : integer := 4;
constant NUM_LUTS     : integer := MATCH_COUNTER_BITS/BITS_PER_LUT;

signal comparison0  : std_logic_vector(NUM_LUTS-1 downto 0);
signal comparison1  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainIn  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainOut : std_logic_vector(NUM_LUTS-1 downto 0);

begin

   GenerateLogic: 
   for index in NUM_LUTS-1 downto 0 generate
      cfglut5_inst : CFGLUT5           -- For simulation  cfglut5_inst : entity work.CFGLUT5
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
         i4  => '1',                         -- Split CFGLUT5 into 2 x LUT4 
         i3  => count(BITS_PER_LUT*index+3), -- Logic data input
         i2  => count(BITS_PER_LUT*index+2), -- Logic data input
         i1  => count(BITS_PER_LUT*index+1), -- Logic data input
         i0  => count(BITS_PER_LUT*index+0), -- Logic data input
         
         o5  => comparison0(index),          -- LUT4 output LUT[15..0]
         o6  => comparison1(index)           -- LUT4 output LUT[31..16]     
      );
   end generate;
   
   SingleLutChainGenerate:
   if (NUM_LUTS = 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(0);
      lut_chainIn(0) <= lut_config_in;
   end generate;
   
   MutipleLutChainGenerate:
   if (NUM_LUTS > 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(lut_chainOut'left);
      lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   end generate;
   
   
   -- Fold output of comparison bits
   equal1 <= and_reduce(comparison1);
   equal0 <= and_reduce(comparison0);
   
end Behavioral;
