library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

--============================================================================
-- Implements a MAX_TRIGGER_STEPS logical operations of MAX_CONDITIONS-wide 
-- MAX_CONDITIONS must be 2 or 4
-- The logical operation value is encoded in the LUT
--============================================================================
entity Combiner is
    port ( 
         -- Trigger logic
         conditions     : in  TriggerConditionArray; 
         -- Trigger output combining conditions
         triggers       : out std_logic_vector(MAX_TRIGGER_STEPS-1 downto 0); 
         
         -- LUT serial configuration NUM_LUTS x 32 bits = NUM_LUTS LUTs
         lut_clock      : in  std_logic;  -- Used for LUT shift register          
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register (MSB first)
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end Combiner;

architecture behavioral of Combiner is

-- Each LUT can implement up to 4 inputs   
constant BITS_PER_LUT       : integer := 4;
constant NUM_LUTS           : integer := (MAX_TRIGGER_STEPS*MAX_CONDITIONS)/BITS_PER_LUT;

signal lut_chainIn  : std_logic_vector(NUM_LUTS-1 downto 0);
signal lut_chainOut : std_logic_vector(NUM_LUTS-1 downto 0);

begin

   GenerateLogic2:
   if (MAX_CONDITIONS = 2) generate

   -- Each LUT implements 2 independent logical operation on 2 Conditions (2 of 2->1 operations)    
   constant CONDITIONS_PER_LUT : integer := 2;
   
   begin
      GenerateLogicBlock2: 
      for index in NUM_LUTS-1 downto 0 generate
      begin
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
            i4  => '1',                                        -- Split CFGLUT5 into 2 x LUT4 
            i3  => conditions(CONDITIONS_PER_LUT*index+1)(1),  -- Logic data input
            i2  => conditions(CONDITIONS_PER_LUT*index+1)(0),  -- Logic data input
            i1  => conditions(CONDITIONS_PER_LUT*index)(1),    -- Logic data input
            i0  => conditions(CONDITIONS_PER_LUT*index)(0),    -- Logic data input
            
            o5  => triggers(CONDITIONS_PER_LUT*index),   -- 4-LUT output
            o6  => triggers(CONDITIONS_PER_LUT*index+1)  -- 4-LUT output
         );
      end generate;
   end generate;
         
   GenerateLogic4:
   if (MAX_CONDITIONS = 4) generate
   begin
      GenerateLogicBlock4: 
      for index in NUM_LUTS-1 downto 0 generate
      begin
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
