library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity clockDivider is
   port ( 
      clock_100Mhz          : in   std_logic;
      reset                 : in   std_logic;
      enable                : in   std_logic;
      sampleEnable          : out  std_logic;
      clockDiv_10_value     : in   std_logic_vector (3 downto 0);
      clockDiv_1_2_5_value  : in   std_logic_vector (1 downto 0)
   );
end clockDivider;

architecture behavioral of clockDivider is

subtype CounterType is unsigned(13 downto 0);

signal div_2_counter       : unsigned( 0 downto 0);
signal div_5_counter       : unsigned( 2 downto 0);
signal div_10_counter      : unsigned( 3 downto 0);
signal div_10n_counter     : CounterType;

signal clock_enable        : std_logic;

-- function div_10_value(div : std_logic_vector (3 downto 0)) return CounterType is
-- begin
   -- case(div) is
      -- when "0000" => return to_unsigned(    1, CounterType'length);
      -- when "0001" => return to_unsigned(    2, CounterType'length);
      -- when "0010" => return to_unsigned(    5, CounterType'length);
      -- when "0011" => return to_unsigned(   10, CounterType'length);
      -- when "0100" => return to_unsigned(   20, CounterType'length);
      -- when "0101" => return to_unsigned(   50, CounterType'length);
      -- when "0110" => return to_unsigned(  100, CounterType'length);
      -- when "0111" => return to_unsigned(  200, CounterType'length);
      -- when "1000" => return to_unsigned(  500, CounterType'length);
      -- when "1001" => return to_unsigned( 1000, CounterType'length);
      -- when "1010" => return to_unsigned( 2000, CounterType'length);
      -- when "1011" => return to_unsigned( 5000, CounterType'length);
      -- when "1100" => return to_unsigned(10000, CounterType'length);
      -- when "1101" => return to_unsigned(    1, CounterType'length);
      -- when "1110" => return to_unsigned(    1, CounterType'length);
      -- when "1111" => return to_unsigned(    1, CounterType'length);
      -- when others => return to_unsigned(    1, CounterType'length);
   -- end case;
-- end function;

begin

   process(clock_100Mhz) 
   
   begin
      if rising_edge(clock_100Mhz) then
         if ((reset = '1') or (enable = '0')) then
            sampleEnable      <= '0';
            div_2_counter     <= (others => '0');
            div_5_counter     <= (others => '0');
            div_10_counter    <= (others => '0');
            div_10n_counter   <= (others => '0');
         else
            div_2_counter     <= div_2_counter + 1;
            
            if (div_5_counter = 4) then
               div_5_counter  <= (others => '0');
            else
               div_5_counter  <= div_5_counter + 1;
            end if;
            
            if (div_10_counter = 9) then
               div_10_counter <= (others => '0');
            else
               div_10_counter <= div_10_counter + 1;
            end if;
                        
            case (clockDiv_1_2_5_value) is
               when "00"   => sampleEnable <= '1';              -- /1
               when "01"   => sampleEnable <= div_2_counter(0); -- /2
               when "10"   => sampleEnable <= div_5_counter(2); -- /5
               when "11"   => sampleEnable <= div_10_counter(3) and div_10_counter(0); -- /10
               when others => sampleEnable <= '1';
            end case;
         end if;
      end if;
   end process;
   
end behavioral;

