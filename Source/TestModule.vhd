--=============================================================
-- Used for module testing with Microcontroller SPI
--=============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.LogicAnalyserPackage.all;

entity TestModule is
   port ( 
      reset       : in  std_logic;
      clock       : in  std_logic;
      switch      : in  std_logic_vector(7 downto 0);
      led         : out std_logic_vector(7 downto 0)
   );
end TestModule;

architecture behavioral of TestModule is

constant NUM_CHAINED_MODULES : positive := 1;

-- Trigger logic
signal currentSample  : SampleDataType; -- Current currentSample data
signal lastSample     : SampleDataType; -- Previous currentSample data
--signal trigger1       : std_logic;      -- Trigger output 1
--signal trigger0       : std_logic;      -- Trigger output 0
signal trigger       : std_logic;      -- Trigger output
signal triggerStep  : TriggerRangeType;  -- Current match counter value

-- LUT serial configuration          
signal lut_clock      : std_logic;  -- Used for LUT shift register          
signal lut_config_ce  : std_logic;  -- Clock enable for LUT shift register
signal lut_config_in  : std_logic;  -- Serial in for LUT shift register MSB first in
signal lut_config_out : std_logic;  -- Serial out for LUT shift register
signal lut_config_out_delayed : std_logic;  -- Serial out for LUT shift register

signal lut_chainIn    : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal lut_chainOut   : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);

signal   edgeDetector    : std_logic_vector(3 downto 0);
constant risingPattern   : std_logic_vector(edgeDetector'left downto 0) := (edgeDetector'left=>'0', others=>'1');
constant fallingPattern  : std_logic_vector(edgeDetector'left downto 0) := (edgeDetector'left=>'1', others=>'0');

signal   lut_config_out_delay   : std_logic_vector(99 downto 0);
 
signal count        : MatchCounterType;  -- Current match counter value
--signal equal        : std_logic;         -- Counter equal for current trigger step

signal toggle : std_logic;

signal enable : std_logic;

begin

-- switch(0) = c(0)  - currentSample
-- switch(1) = c(1)  - currentSample
-- switch(2) = c(2)  - lastSample
-- switch(3) = c(3)  - lastSample
-- switch(4) = c(4)  - lut_clock (effective)
-- switch(5) = c(5)  - lut_config_in
-- switch(6) = c(6)  - 
-- switch(7) = c(7)  - enable

-- led(0)    = c(8)  - lut_config_out
-- led(1)    = c(9)  - lut_config_ce
-- led(2)    = c(10) -
-- led(3)    = c(11) -
-- led(4)    = c(12) - toggle
-- led(5)    = c(13) - sw(6)
-- led(6)    = c(14) - 
-- led(7)    = c(15) - trigger



-- switch(0) = c(0)  - count(0)
-- switch(1) = c(1)  - count(1)
-- switch(2) = c(2)  - count(2)
-- switch(3) = c(3)  - count(3)
-- switch(4) = c(4)  - lut_clock (effective)
-- switch(5) = c(5)  - lut_config_in
-- switch(6) = c(6)  - triggerStep(0)
-- switch(7) = c(7)  - triggerStep(1)

-- led(0)    = c(8)  - lut_config_out
-- led(1)    = c(9)  - lut_config_ce
-- led(2)    = c(10) -
-- led(3)    = c(11) -
-- led(4)    = c(12) - toggle
-- led(5)    = c(13) - sw(6)
-- led(6)    = c(14) - 
-- led(7)    = c(15) - trigger

   edgedetect:
   process(reset, clock)
   variable pulse : std_logic;
   begin
      if (reset = '1') then
         edgeDetector <= (others => '0');
         pulse := '0';
      elsif rising_edge(clock) then
         edgeDetector <= edgeDetector(edgeDetector'left-1 downto 0) & switch(4);
         lut_config_ce <= '0';
         if (pulse = '1') then
            if (edgeDetector = fallingPattern) then
               pulse := '0';
            end if;
         else
            lut_config_out_delayed <= lut_config_out;
            if (edgeDetector = risingPattern) then
               pulse         := '1';
               lut_config_ce <= '1';
            end if;
         end if;
         
      end if;
   end process;

   outDelay:
   process(reset, clock)
   begin
      if (reset = '1') then
         lut_config_out_delay <= (others => '0');
      elsif rising_edge(clock) then
         lut_config_out_delay <= lut_config_out_delay(lut_config_out_delay'left-1 downto 0) & lut_config_out;
      end if;
   end process;

--   lut_config_ce <= '1' when (edgeDetector = risingPattern) else '0';
   lut_clock     <= clock;

   count(3 downto 0)          <= unsigned(switch(3 downto 0));
   count(count'left downto 4) <= (others => '0');
   currentSample <= switch(1 downto 0);
   lastSample    <= switch(3 downto 2);
   lut_config_in <= switch(5);
--   triggerStep   <= to_integer(unsigned(switch(7 downto 6)));
   enable <= switch(7);

   --lut_config_out_delayed <= lut_config_out_delay(lut_config_out_delay'left);
   led(0) <= lut_config_out_delayed; 
   led(1) <= lut_config_ce; -- edgeDetector(edgeDetector'left-1);
   
   led(3 downto 2) <= (others => '0');

   toggle <= not toggle when rising_edge(clock);
   led(4) <= toggle;
   led(5) <= '0';
   led(6) <= '0';
   led(7) <= trigger;   
      
   TriggerBlock_inst:
   entity work.TriggerBlock
   port map ( 
      reset          => reset,
      clock          => clock,
      
      -- Trigger logic
      enable        => enable,
      currentSample => currentSample,       -- Current sample data
      lastSample    => lastSample,          -- Prevous sample data
      
      trigger       => trigger,             -- Trigger output

      lut_clock      => lut_clock,       -- Used for LUT shift register          
      lut_config_ce  => lut_config_ce,   -- Clock enable for LUT shift register
      lut_config_in  => lut_chainIn(0),  -- Serial in for LUT shift register (MSB first)
      lut_config_out => lut_chainOut(0)  -- Serial out for LUT shift register
  );

--   CountMatchers_inst:
--   entity work.CountMatchers
--   port map (
--      -- Logic function
--      count        => count,             -- Current match counter value
--      triggerStep  => triggerStep,       -- Current match counter value
--      equal        => equal,             -- Counter equal for current trigger step
-- 
--      -- LUT serial configuration (NUM_INPUTS/2 LUTs)
--      lut_clock      => lut_clock,       -- Used for LUT shift register          
--      lut_config_ce  => lut_config_ce,   -- Clock enable for LUT shift register
--      lut_config_in  => lut_chainIn(0),  -- Serial in for LUT shift register (MSB first)
--      lut_config_out => lut_chainOut(0)  -- Serial out for LUT shift register
--   );

--   TriggerMatches_inst:
--   entity work.PatternMatchers
--   port map (
--      -- Logic function
--      currentSample => currentSample,       -- Current sample data
--      lastSample    => lastSample,          -- Prevous sample data
--      triggerStep   => triggerStep,         -- Current match counter value
--      trigger       => trigger,             -- Trigger output
--
--      -- LUT serial configuration (NUM_INPUTS/2 LUTs)
--      lut_clock      => lut_clock,       -- Used for LUT shift register          
--      lut_config_ce  => lut_config_ce,   -- Clock enable for LUT shift register
--      lut_config_in  => lut_chainIn(0),  -- Serial in for LUT shift register (MSB first)
--      lut_config_out => lut_chainOut(0)  -- Serial out for LUT shift register
--   );

--   PatternMatcher_inst:
--   entity work.PatternMatcher
--   port map (
--      -- Logic function
--      currentSample => currentSample,       -- Current sample data
--      lastSample    => lastSample,          -- Prevous sample data
--      
--      trigger1      => trigger1,  -- Comparison output
--      trigger0      => trigger0,  -- Comparison output
--
--      -- LUT serial configuration (NUM_INPUTS/2 LUTs)
--      lut_clock      => lut_clock,       -- Used for LUT shift register          
--      lut_config_ce  => lut_config_ce,   -- Clock enable for LUT shift register
--      lut_config_in  => lut_chainIn(0),  -- Serial in for LUT shift register (MSB first)
--      lut_config_out => lut_chainOut(0)  -- Serial out for LUT shift register
--   );

--   ConfigData_inst:
--   entity work.ConfigData
--      port map (
--         reset          => reset,
--         -- LUT serial configuration          
--         lut_clock      => lut_clock,      -- Used for LUT shift register          
--         lut_config_ce  => lut_config_ce,  -- Clock enable for LUT shift register
--         lut_config_in  => lut_chainIn(1), -- Serial in for LUT shift register MSB first in
--         lut_config_out => lut_chainOut(1) -- Serial out for LUT shift register
--      );

   SingleLutChainGenerate:
   if (NUM_CHAINED_MODULES = 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(0);
      lut_chainIn(0) <= lut_config_in;
   end generate;
   
   MutipleLutChainGenerate:
   if (NUM_CHAINED_MODULES > 1) generate
   begin
      -- Chain LUT shift-registers
      lut_config_out <= lut_chainOut(lut_chainOut'left);
      lut_chainIn    <= lut_chainOut(lut_chainOut'left-1 downto 0) & lut_config_in;
   end generate;
      
end behavioral;

