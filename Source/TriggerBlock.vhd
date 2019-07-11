library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;

--==============================================================================================
-- Implements MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS of NUM_INPUTS-wide trigger circuits supporting 
--
--    High    Low     Rising     Falling     Change
--    -----              +---   ---+        ---+ +---
--                      /           \           X
--           -----  ---+             +---   ---+ +---
-- The trigger condition is encoded in the LUT.
--
-- The current trigger is selected by triggerStep.
--
-- LUT serial configuration:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS)/4 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16
--
-- Example LUT bit mapping in LUT chain(MAX_TRIGGER_STEPS=16, MAX_TRIGGER_CONDITIONS=4, NUM_INPUTS=16)
--
-- Number of LUTs:
--   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 = 16 * 4/2 * 16/2 = 256 LUTs
--   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/4                = 16 * 4/4        =  16 LUTs
--   Flags:       NUM_FLAGS * MAX_TRIGGER_STEPS/16                    =  2 * 16/16      =   2 LUT
-- TODO
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
-- |   Flag(1)   |   Flag(0)   |  Combiner   | Trigger 15  | Trigger 14  | ...    ... | Trigger 1   | Trigger 0   |
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
-- |  LUT(274)   |  LUT(273)   |LUT(272..256)|LUT(255..240)|LUT(239..224)|            | LUT(31..16) |  LUT(15..0) |
-- +-------------+-------------+-------------+-------------+-------------+------------+-------------+-------------+
--   See                                     |             |
--   StepFlags     +-------------------------+             |
--   and           |                                       |
--   Combiner      +-------------------+-------------------+
--                 |  TriggerMatcher   |  TriggerMatcher   |  See TriggerMatcher
--                 |   LUT(255..248)   |   LUT(247..240)   |  for detailed mapping (8 LUTs)
--                 +-------------------+-------------------+
--
--==============================================================================================
entity TriggerBlock is
   port ( 
      reset          : in  std_logic;
      clock          : in  std_logic;
      
      -- Trigger logic
      enable         : in  std_logic;
      lastSample     : in  SampleDataType;
      currentSample  : in  SampleDataType;
      
      trigger        : out std_logic;      -- Trigger output

      -- LUT serial configuration          
      lut_clock      : in  std_logic;  -- Used for LUT shift register          
      lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in  : in  std_logic;  -- Serial in for LUT shift register MSB first in
      lut_config_out : out std_logic   -- Serial out for LUT shift register
  );
end TriggerBlock;

architecture Behavioral of TriggerBlock is

type StateType is (s_idle, s_running, s_complete);
signal state : StateType;

signal triggerFound : std_logic;

signal triggerCountEquals : std_logic;

signal matchCounter : MatchCounterType;

signal lut_chain : std_logic;

signal triggerStep  : TriggerRangeType;

constant NUM_FLAGS : integer := 2;
signal flags : std_logic_vector(NUM_FLAGS-1 downto 0);

alias  contiguousTrigger : std_logic is flags(0);
alias  lastTriggerStep   : std_logic is flags(1);

signal lut_chainIn  : std_logic_vector(2 downto 0);
signal lut_chainOut : std_logic_vector(2 downto 0);

begin
   
   TriggerMatches_inst:
   entity work.TriggerMatches
   port map ( 
      -- Trigger logic
      currentSample => currentSample,  -- Current sample data
      lastSample    => lastSample,     -- Previous sample data
      triggerStep   => triggerStep,    -- Current step in trigger sequence

      trigger       => triggerFound,   -- Trigger found for current step

      -- LUT serial configuration:
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS)/4 LUTs
      lut_clock      => lut_clock,        -- LUT shift-register clock
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(0),   -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(0)   -- Serial configuration data output
   );

   CountMatches_inst:
   entity work.CountMatches
   port map ( 
      -- Trigger logic
      count         => matchCounter,         -- Current match counter
      triggerStep   => triggerStep,          -- Current step in trigger sequence

      equal         => triggerCountEquals,   -- Comparator outputs

      -- LUT serial configuration:
      --   Comparators: MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS/2 * NUM_INPUTS/2 LUTs
      --   Combiner:    MAX_TRIGGER_STEPS * MAX_TRIGGER_CONDITIONS)/4 LUTs
      lut_clock      => lut_clock,        -- LUT shift-register clock
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(1),   -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(1)   -- Serial configuration data output
   );

   StepFlags_inst:
   entity work.StepFlags
   generic map (
      NUM_FLAGS => NUM_FLAGS
   )
   port map ( 
      -- Trigger logic
      triggerStep   => triggerStep,          -- Current step in trigger sequence
      flags         => flags,                -- Comparator outputs

      -- LUT serial configuration 
      -- MAX_TRIGGER_STEPS * MATCH_COUNTER_BITS/4 x 32 bits = MAX_TRIGGER_CONDITIONS * NUM_INPUTS/2 LUTs
      lut_clock      => lut_clock,        -- LUT shift-register clock
      lut_config_ce  => lut_config_ce,    -- LUT shift-register clock enable
      lut_config_in  => lut_chainIn(2),   -- Serial configuration data input (MSB first)
      lut_config_out => lut_chainOut(2)   -- Serial configuration data output
   );

   -- Wire LUT shift registers as single chain
   lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   lut_config_out <= lut_chainOut(lut_chainOut'left);
   
   triggerStateMachine:
   process(reset, clock, triggerFound, triggerStep) 

   begin      
       
      if (reset = '1') then
         state       <= s_idle;
         triggerStep <= 0;
         trigger     <= '0';
      elsif rising_edge(clock) then
         case (state) is
            when s_idle =>
               triggerStep  <= 0;
               trigger      <= '0';
               matchCounter <= (others => '0');
               if (enable = '1') then
                  state <= s_running;
               end if;
            when s_running =>
               if (enable = '0') then
                  state <= s_idle;
               end if;
               if (triggerFound = '1') then
                  matchCounter <= matchCounter + 1;
                  if (triggerCountEquals = '1') then                     
                     if (lastTriggerStep = '1') then
                        trigger <= '1';
                        state   <= s_complete;
                     else
                        triggerStep  <= triggerStep + 1;
                        matchCounter <= (others => '0');
                     end if;
                  end if;
               else
                  if (contiguousTrigger = '1') then
                     -- Counter reset on break in matches
                     matchCounter <= (others => '0');
                  end if;
               end if;
            when s_complete =>
               trigger <= '0';
               if (enable = '0') then
                  state <= s_idle;
               end if;
         end case;
      end if;
   end process;

end Behavioral;

