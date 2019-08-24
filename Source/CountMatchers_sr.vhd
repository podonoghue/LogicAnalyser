library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity CountMatchers_sr is
   port( 
      -- Count of matches for current step
      matchCounter      : in  MatchCounterType;
      
      -- Which step in trigger sequence
      triggerStep       : in  TriggerRangeType;

      -- Counter equal for each current step
      triggerCountMatch : out std_logic; 
                                 
      -- LUT serial configuration 
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_PATTERNS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS*MAX_TRIGGER_PATTERNS/4 LUTs
      --   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
      clock             : in  std_logic;  -- Used to clock LUT chain
      lut_config_ce     : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in     : in  std_logic;  -- Serial in for LUT shift register (MSB first)
      lut_config_out    : out std_logic   -- Serial out for LUT shift register
   );
end entity;

architecture Behavioral of CountMatchers_sr is

signal comparematchCounter : MatchCounterType;

-- Number of modules chained together
constant NUM_CHAINED_MODULES   : integer := NUM_MATCH_COUNTER_BITS;
signal   lut_chainIn           : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal   lut_chainOut          : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);

begin

   triggerCountMatch <= '1' when (compareMatchCounter = matchCounter) else '0';

   GenerateSteps: -- Each trigger step
   for counterBits in NUM_MATCH_COUNTER_BITS-1 downto 0 generate
   
   begin
      cfglut5_inst : cfglut5
      generic map (
         init => x"00000000"
      )
      port map (
         -- Reconfigure shift register
         clk => clock,                     -- LUT shift-register clock
         ce  => lut_config_ce,             -- LUT shift-register clock enable
         cdi => lut_chainIn(counterBits),  -- Serial configuration data input (MSB first)
         cdo => lut_chainOut(counterBits), -- Serial configuration data output
         
         -- Logic function inputs
         i4  => '1',  -- Split CFGLUT5 into 2 x LUT4 
         
         i3  => triggerStep(3), -- Logic data input
         i2  => triggerStep(2), -- Logic data input
         i1  => triggerStep(1), -- Logic data input
         i0  => triggerStep(0), -- Logic data input
         
         o5  => compareMatchCounter(counterBits), -- LUT4 output LUT[15..0]
         o6  => open                              -- LUT4 output LUT[31..16]     
      );
   end generate;
  
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

