library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

--=================================================================
-- Implements simple LUT to provide flags for each trigger step
-- The flags are encoded in the LUT
--
-- LUT serial configuration:
-- NUM_FLAGS LUTs
--
-- Each LUT implements 1 flag.
--
-- Example LUT bit mapping in LUT chain(NUM_FLAGS=2)
-- NUM_INPUTS/2 LUTs =>16/2 = 8
--
-- +-----------+-----------+
-- |  LUT(1)   |  LUT(0)   |
-- +-----------+-----------+
-- |  Flag(1)  |  Flag(0)  |
-- +-----------+-----------+
--             |           |
-- +-----------+           +---------------------------------------+
-- |                                                               |
-- |             Mapping for an typical LUT                        |
-- +---------------------------------------------------------------+
-- |3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                    | 
-- |1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0| <- LUT bit #
-- +---------------+---------------+---------------+---------------+
-- The CFGLUT5 are treated as LUT5. Each LUT5 provides 1 flag
--=================================================================
entity StepFlags is
    generic (
         NUM_FLAGS : integer := 2
    );
    port ( 
         -- Current match counter value
         triggerStep    : in  TriggerRangeType; 
         
         -- Flag values
         flags          : out std_logic_vector(NUM_FLAGS-1 downto 0);        

         -- LUT serial configuration NUM_LUTS x 32 bits = NUM_LUTS LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end StepFlags;

architecture behavioral of StepFlags is

constant NUM_LUTS   : integer := NUM_FLAGS;

signal lut_chainIn  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainOut : std_logic_vector(NUM_LUTS-1 downto 0);
signal stepValue    : unsigned(4 downto 0); 

begin

   stepValue <= to_unsigned(triggerStep, stepValue'length);
   
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
         i4  => stepValue(4), -- Logic data input 
         i3  => stepValue(3), -- Logic data input
         i2  => stepValue(2), -- Logic data input
         i1  => stepValue(1), -- Logic data input
         i0  => stepValue(0), -- Logic data input
         
         o5  => open,           -- Not used
         o6  => flags(index)    -- 5-LUT output      
      );
   end generate;
   
   -- Chain LUT shift-registers
   lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   lut_config_out <= lut_chainOut(lut_chainOut'left);
      
end Behavioral;
