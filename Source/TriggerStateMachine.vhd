library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity TriggerStateMachine is
    port ( clock                 : in   std_logic;
           reset                 : in   std_logic;
           
           enable                : in   std_logic;
           triggerCountMatch     : in   std_logic;
           triggerPatternMatch   : in   std_logic;
           lastTriggerStep       : in   std_logic;
           contiguousTrigger     : in   std_logic;

           matchCount            : out  MatchCounterType;
           triggerStep           : out  TriggerRangeType;
           triggerFound          : out  std_logic
     );
end TriggerStateMachine;

architecture behavioral of TriggerStateMachine is

type StateType is (s_idle, s_running, s_complete);

signal state          : StateType;
signal stepCounter    : TriggerRangeType;
signal matchCounter   : MatchCounterType;
signal enableSynced   : std_logic;

begin

   triggerStep  <= stepCounter;
   matchCount   <= matchCounter;
   
   enableSynced <= enable and not reset when rising_edge(clock);
   
   triggerStateMachine:
   process(clock) 
   
   -- Used to implement Galois 16-bit LFSRs
   function lfsr16(current : MatchCounterType) return MatchCounterType is
   begin
      return 
         current(0)&
         current(15)&
         (current(14) xor current(0))&
         (current(13) xor current(0))&
         current(12)&
         (current(11) xor current(0))&
         current(10 downto 1);
   end;
   
   begin      
      if rising_edge(clock) then
         if ((reset = '1') or (enableSynced = '0')) then
            state        <= s_idle;
            stepCounter  <= (others =>'0');
            matchCounter <= (0=>'1', others =>'0'); 
            triggerFound <= '0';
         else 
            case (state) is
            
            when s_idle =>
               stepCounter  <= (others =>'0');
               triggerFound <= '0';
               matchCounter <= (0=>'1', others =>'0');
               state        <= s_running;
            
            when s_running =>
               if (triggerPatternMatch   = '1') then
                  matchCounter <= lfsr16(matchCounter);
                  if (triggerCountMatch  = '1') then                     
                     if (lastTriggerStep = '1') then
                        triggerFound <= '1';
                        state        <= s_complete;
                     else
                        stepCounter  <= stepCounter + 1;
                        matchCounter <= (0=>'1', others =>'0');
                     end if;
                  end if;
               else
                  if (contiguousTrigger = '1') then
                     -- Counter cleared on break in matches
                     matchCounter <= (0=>'1', others =>'0');
                  end if;
               end if;
            
            when s_complete =>
               triggerFound <= '0';
            end case;
         end if;
      end if;
   end process;

end behavioral;

