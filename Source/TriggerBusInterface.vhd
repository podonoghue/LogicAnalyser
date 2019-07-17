library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity TriggerBusInterface is
   Port ( 
      reset          : in   std_logic;
      clock          : in   std_logic;
      dataIn         : in   DataBusType;
      dataOut        : out  DataBusType;
      addr           : in   AddressBusType;
      wr             : in   std_logic;
      rd             : in   std_logic;

      -- LUT serial configuration          
      lut_config_ce  : out std_logic;  -- Clock enable for LUT shift register
      lut_config_in  : out std_logic;  -- Serial in for LUT shift register (MSB first)
      lut_config_out : in  std_logic   -- Serial out for LUT shift register
     );
end TriggerBusInterface;

architecture Behavioral of TriggerBusInterface is

type StateType is (s_idle, s_write, s_release);
signal state : StateType;

signal bitCount  : integer range 0 to DataBusType'length-1;
signal dataShiftRegister : DataBusType;

signal ce : std_logic;

begin

   lut_config_in <= dataShiftRegister(dataShiftRegister'left);
   ce <= '1' when (to_integer(addr) = LUT_SR_ADDRESS) else '0';
   
   ReadProc:
   process(rd, dataShiftRegister)
   begin
      dataOut <= (others => '0');
      if (rd = '1') then
         dataOut <= dataShiftRegister;
      end if;   
   end process;
   
   WriteProc:
   process(reset, clock)
   begin
      if (reset = '1') then
         state              <= s_idle;
         lut_config_ce      <= '0';
         dataShiftRegister  <= (others => '0');
         bitCount           <= 0;
      elsif rising_edge(clock) then
         case (state) is
         
            when s_idle =>
               if ((ce = '1') and(wr = '1')) then
                  state             <= s_write;
                  dataShiftRegister <= dataIn;
                  lut_config_ce     <= '1';
               end if;
               
            when s_write =>
               dataShiftRegister  <= dataShiftRegister(dataShiftRegister'left-1 downto 0) & lut_config_out;
               if (bitCount = dataShiftRegister'left) then
                  state         <= s_release;
                  lut_config_ce <= '0';
                  bitCount      <= 0;
               else
                  bitCount <= bitCount + 1;
               end if;
               
            when s_release =>
               if (wr = '0') then
                  state <= s_idle;
               end if;               
         end case;
      end if;
   end process;

end Behavioral;

