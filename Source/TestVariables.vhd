----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:08:39 07/20/2019 
-- Design Name: 
-- Module Name:    TestVariables - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestVariables is
Port ( 
   clock    : in   STD_LOGIC;
   change   : in   STD_LOGIC;
   state_o  : out  natural range 1 to 3
);
end TestVariables;

architecture Behavioral of TestVariables is

type StateType is (s_1, s_2, s_3);
signal state : StateType;

begin
   
   process(clock)

--   variable nextState : StateType;

   begin
      if rising_edge(clock) then
--         nextState := state;
         case(state) is
            when s_1 =>
               state <= s_2;
            when s_2 =>
               if (change = '1') then
                  state <= s_2;
               end if;
            when s_3 =>
               state <= s_1;
         end case;
--         state     <= nextState;
      end if;
   end process;

   process(state)
   begin
      case(state) is
         when s_1 =>
            state_o <= 1;
         when s_2 =>
            state_o <= 2;
         when s_3 =>
            state_o <= 3;
      end case;
   end process;
   
end Behavioral;

