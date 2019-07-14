library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real."floor";
use IEEE.math_real."log2";

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

entity ConfigData is
   port (
      reset          : in  std_logic;
      
      -- LUT serial configuration          
      lut_clock      : in  std_logic;  -- Used for LUT shift register          
      lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in  : in  std_logic;  -- Serial in for LUT shift register MSB first in
      lut_config_out : out std_logic   -- Serial out for LUT shift register
   );
end ConfigData;

architecture Behavioral of ConfigData is

   function int_to_bit_vector(value : integer; width : integer) return bit_vector is
   begin
      return to_bitvector(std_ulogic_vector(to_unsigned(value, width)));
   end int_to_bit_vector;

   subtype ConfigByte is integer;
   subtype ConfigWord is bit_vector(31 downto 0);
   
   function ints_to_config_word(byte0 : ConfigByte; byte1 : ConfigByte; byte2 : ConfigByte; byte3 : ConfigByte) return ConfigWord is
   begin
      return int_to_bit_vector(byte0, 8)&
             int_to_bit_vector(byte1, 8)&
             int_to_bit_vector(byte2, 8)&
             int_to_bit_vector(byte3, 8);
   end ints_to_config_word;
   
   -- Number of bit necessary to select a configuration word
   constant NUM_SEL_BITS       : positive := 2;

   -- Number of bit necessary to select a bit within a configuration word
   constant NUM_BIT_ADDR_BITS  : positive := 5;

   -- Number of configuration WORDS/LUTS
   constant NUM_CONFIG_WORDS   : positive := 2**NUM_SEL_BITS;

   -- Key used to confirm configuration information
   constant CONFIG_KEY : bit_vector(31 downto 0) := x"A55E1234";

   -- Configation information
   type ConfigInformation is array (NUM_CONFIG_WORDS-1 downto 0) of ConfigWord;

   -- Configuration information for readout
   constant configInfo : ConfigInformation := (
      CONFIG_KEY,
      ints_to_config_word(SAMPLE_WIDTH, MAX_TRIGGER_STEPS, MAX_TRIGGER_CONDITIONS, MATCH_COUNTER_BITS),
      others=>x"00000000"
   );

   -- Counter indexing configuration words and bits
   signal   count          : unsigned((NUM_SEL_BITS+NUM_BIT_ADDR_BITS)-1 downto 0);
   constant COUNT_MAX      : unsigned((NUM_SEL_BITS+NUM_BIT_ADDR_BITS)-1 downto 0) := (others => '1');
   constant COUNT_MIN      : unsigned((NUM_SEL_BITS+NUM_BIT_ADDR_BITS)-1 downto 0) := (others => '0');

   -- Selects configuration words
   signal   sel            : natural range 0 to 3;--(2**NUM_SEL_BITS)-1;

   -- Selects bits within a configuration word
   signal   bit_addr       : std_logic_vector(NUM_BIT_ADDR_BITS-1 downto 0);

   -- Multiplexes configuration bits
   signal configDataValue  : std_logic_vector(NUM_CONFIG_WORDS-1 downto 0);

   type Statetype is (active, idle);
   signal state            : Statetype;

begin
   bit_addr <= std_logic_vector(count(bit_addr'left downto 0));
   sel      <= to_integer(count(count'left downto bit_addr'left+1));
   
   sync:
   process(reset, lut_clock) 
   begin
      if (reset = '1') then
         state <= active;
         count <= COUNT_MAX;
      elsif rising_edge(lut_clock) then
         if (lut_config_ce = '1') then
            case state is
               when idle =>
                  -- bypass config
                  count <= (others => '0');
               when active =>
                  -- config active
                  count <= count - "1";
                  if (count = COUNT_MIN) then
                     state <= idle;
                  end if;
            end case;
         end if;
      end if;
   end process;

   mux:
   process(state, lut_config_in, configDataValue, sel)
   begin
      case state is
         when idle =>
            -- bypass config
            lut_config_out <= lut_config_in;
         when active =>
            -- config active
            lut_config_out <= configDataValue(sel);
      end case;
   end process;

   ConfigGenerate:
   for index in configInfo'left downto configInfo'right generate
   begin
      SRLC32E_inst : SRLC32E
      generic map (
         init => configInfo(index)
      )
      port map (
         clk   => '0',                    -- LUT shift-register clock
         ce    => '0',                    -- LUT shift-register clock enable

         Q     => configDataValue(index), -- SRL data output
         Q31   => open,                   -- SRL cascade output pin
         A     => bit_addr,               -- 5-bit shift depth select input
         D     => '0'                     -- SRL data input
      );
   end generate;

end Behavioral;

