library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

--=================================================================
-- Implements 2 of NUM_INPUTS-wide trigger comparators supporting 
--
--    High    Low     Rising     Falling     Change
--    -----              +---   ---+        ---+ +---
--                      /           \           X
--           -----  ---+             +---   ---+ +---
-- The trigger condition is encoded in the LUT
--
-- LUT serial configuration:
-- NUM_INPUTS/2 LUTs => NUM_INPUTS/2 x 32 bits
--
-- Each LUT implements 2 bits of 2 N-bit comparators.
--
-- Example LUT bit mapping in LUT chain(NUM_INPUTS=16)
-- NUM_INPUTS/2 LUTs =>16/2 = 8
--
-- +-----------+-----------+       +-----------+-----------+           
-- |  LUT(7)   |  LUT(6)   |.......|  LUT(1)   |   LUT(0)  | <- LUT i chain
-- +-----------+-----------+       +-----------+-----------+
-- | 15  | 14  | 13  | 12  |       |  3  |  2  |  1  |  0  | <- Input bit #
--             |           |
-- +-----------+           +---------------------------------------+
-- |                                                               |
-- |             Mapping for an typical LUT                        |
-- +---------------------------------------------------------------+
-- |3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1                    | 
-- |1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0| <- LUT bit #
-- +---------------+---------------+---------------+---------------+
-- |          TRIGGER 1            |           TRIGGER 0           | <- Pair of Comparator values
-- +---------------+---------------+---------------+---------------+
-- |     Bit 13    |    Bit 12     |    Bit 13     |    Bit 12     | <- Input bit #
-- +---------------+---------------+---------------+---------------+
-- The CFGLUT5 are treated as 2 x LUT4s. Each LUT4 handles 2 input bits.
--
--======================================================================================

entity TriggerMatcher is
    port ( 
         -- Trigger logic
         currentSample  : in  SampleDataType; -- Current currentSample data
         lastSample     : in  SampleDataType; -- Previous currentSample data
         trigger1       : out std_logic;      -- Trigger output 1
         trigger0       : out std_logic;      -- Trigger output 0

         -- LUT serial configuration: NUM_INPUTS/2 LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end TriggerMatcher;

architecture behavioral of TriggerMatcher is

-- Each LUT implements a 2-bit trigger detector
constant BITS_PER_LUT : integer := 2;
constant NUM_LUTS     : integer := NUM_INPUTS/BITS_PER_LUT;

signal comparison1  : std_logic_vector(NUM_LUTS-1 downto 0);
signal comparison0  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainIn  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainOut : std_logic_vector(NUM_LUTS-1 downto 0);

-- LUT value for detecting given condition on a 2-bit input
-- X=Don't care, 
-- H=High, 
-- L=Low, 
-- R=Rising(0->1), 
-- F=Falling(1->0),
-- C=Changing(1->0 or 0->1) 
-- 
--               111111
--               5432109876543210
constant T_XX : std_logic_vector(15 downto 0) := "1111111111111111";
constant T_XH : std_logic_vector(15 downto 0) := "1010101010101010";
constant T_XL : std_logic_vector(15 downto 0) := "0101010101010101";
constant T_XR : std_logic_vector(15 downto 0) := "0010001000100010";
constant T_XF : std_logic_vector(15 downto 0) := "0100010001000100";
constant T_XC : std_logic_vector(15 downto 0) := "0110011001100110";
constant T_HX : std_logic_vector(15 downto 0) := "1111000011110000";
constant T_HH : std_logic_vector(15 downto 0) := "1010000010100000";
constant T_HL : std_logic_vector(15 downto 0) := "0101000001010000";
constant T_HR : std_logic_vector(15 downto 0) := "0010000000100000";
constant T_HF : std_logic_vector(15 downto 0) := "0100000001000000";
constant T_HC : std_logic_vector(15 downto 0) := "0110000001100000";
constant T_LX : std_logic_vector(15 downto 0) := "0000111100001111";
constant T_LH : std_logic_vector(15 downto 0) := "0000101000001010";
constant T_LL : std_logic_vector(15 downto 0) := "0000010100000101";
constant T_LR : std_logic_vector(15 downto 0) := "0000001000000010";
constant T_LF : std_logic_vector(15 downto 0) := "0000010000000100";
constant T_LC : std_logic_vector(15 downto 0) := "0000011000000110";
constant T_RX : std_logic_vector(15 downto 0) := "0000000011110000";
constant T_RH : std_logic_vector(15 downto 0) := "0000000010100000";
constant T_RL : std_logic_vector(15 downto 0) := "0000000001010000";
constant T_RR : std_logic_vector(15 downto 0) := "0000000000100000";
constant T_RF : std_logic_vector(15 downto 0) := "0000000001000000";
constant T_RC : std_logic_vector(15 downto 0) := "0000000001100000";
constant T_FX : std_logic_vector(15 downto 0) := "0000111100000000";
constant T_FH : std_logic_vector(15 downto 0) := "0000101000000000";
constant T_FL : std_logic_vector(15 downto 0) := "0000010100000000";
constant T_FR : std_logic_vector(15 downto 0) := "0000001000000000";
constant T_FF : std_logic_vector(15 downto 0) := "0000010000000000";
constant T_FC : std_logic_vector(15 downto 0) := "0000011000000000";
constant T_CX : std_logic_vector(15 downto 0) := "0000111111110000";
constant T_CH : std_logic_vector(15 downto 0) := "0000101010100000";
constant T_CL : std_logic_vector(15 downto 0) := "0000010101010000";
constant T_CR : std_logic_vector(15 downto 0) := "0000001000100000";
constant T_CF : std_logic_vector(15 downto 0) := "0000010001000000";
constant T_CC : std_logic_vector(15 downto 0) := "0000011001100000";
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
         -- 2 x LUT4s
         -- INIT[31:16] => O6
         -- INIT[15:0]  => O5
         i4  => '1',                                  -- Split CFGLUT5 into 2 x LUT4 
         i3  => lastSample(BITS_PER_LUT*index+1),     -- Logic data input
         i2  => currentSample(BITS_PER_LUT*index+1),  -- Logic data input
         i1  => lastSample(BITS_PER_LUT*index),       -- Logic data input
         i0  => currentSample(BITS_PER_LUT*index),    -- Logic data input
         
         o6  => comparison1(index),                   -- 4-LUT output      
         o5  => comparison0(index)                    -- 4-LUT output
      );
   end generate;
   
   -- Chain LUT shift-registers
   lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   lut_config_out <= lut_chainOut(lut_chainOut'left);
   
   -- Fold output of comparison bits
   trigger1 <= and_reduce(comparison1);
   trigger0 <= and_reduce(comparison0);
   
end Behavioral;
