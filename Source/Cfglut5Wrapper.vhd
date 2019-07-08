----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:12:10 07/07/2019 
-- Design Name: 
-- Module Name:    TestCfglut5 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

--library UNISIM;
--use UNISIM.VComponents.all;

entity Cfglut5Wrapper is
    port ( 
         --reset      : in  std_logic;
         clock      : in  std_logic;
         
         -- Trigger logic
         currentSample  : in  std_logic;      -- Current sample data
         lastSample     : in  std_logic;      -- Previous sample data
         mode           : in  std_logic;      -- Mode of operation of trigger circuit
         trigger        : out std_logic;      -- Trigger output

         -- LUT serial configuration NUM_INPUTS/2 x 32 bits = NUM_INPUTS/2 LUTs
         lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
         lut_config_in  : in  std_logic;  -- Serial in for LUT shift register
         lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end Cfglut5Wrapper;

architecture Behavioral of Cfglut5Wrapper is

begin
   -- CFGLUT5: Reconfigurable 5-input LUT 
   --          Spartan-6
   -- Xilinx HDL Language Template, version 14.7
      cfglut5_inst : entity work.CFGLUT5
      generic map (
         init => x"00000000"
      )
      port map (
         -- Reconfigure shift register
         clk => clock,                 -- Clock input
         ce  => lut_config_ce,         -- Clock enable
         cdi => lut_config_in,         -- Serial configuration data input (MSB first in)
         cdo => lut_config_out,        -- Serial configuration data output
         
         -- Logic function
         i4  => mode,                  -- Logic data input
         i3  => lastsample,            -- Logic data input
         i2  => currentSample,         -- Logic data input
         i1  => lastSample,            -- Logic data input
         i0  => currentSample,         -- Logic data input
         
         o5  => open,                  -- 4-LUT output
         o6  => trigger                -- 5-LUT output      
      );


end Behavioral;

