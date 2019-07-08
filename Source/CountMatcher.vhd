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
--=================================================================
entity CountMatcher is
    port ( 
         -- Trigger logic
         count      : in  MatchCounterType; -- Current match counter value
         equalA     : out std_logic;        -- Comparator output A
         equalB     : out std_logic;        -- Comparator output B

         -- LUT serial configuration NUM_LUTS x 32 bits = NUM_LUTS LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end CountMatcher;

architecture behavioral of CountMatcher is

-- Each LUT implements a 4-bits of the comparator   
constant BITS_PER_LUT : integer := 4;
constant NUM_LUTS     : integer := MATCH_COUNTER_BITS/BITS_PER_LUT;

signal comparisonA  : std_logic_vector(NUM_LUTS-1 downto 0);
signal comparisonB  : std_logic_vector(NUM_LUTS-1 downto 0);
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
         
         o5  => comparisonA(index),          -- 4-LUT output
         o6  => comparisonB(index)           -- 4-LUT output      
      );
   end generate;
   
   -- Chain LUT shift-registers
   lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   lut_config_out <= lut_chainOut(lut_chainOut'left);
   
   -- Fold output of comparison bits
   equalA <= and_reduce(comparisonA);
   equalB <= and_reduce(comparisonB);
   
end Behavioral;
