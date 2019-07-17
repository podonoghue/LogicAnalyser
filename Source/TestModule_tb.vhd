--======================================================
-- Used to test modeule tester
--======================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY TestModule_tb IS
END TestModule_tb;

ARCHITECTURE behavior OF TestModule_tb IS
 
constant clock_period : time := 10 ns;
signal complete    : boolean := false;

signal reset       : std_logic := '1';
signal clock       : std_logic := '0';
 
signal switch      : std_logic_vector(7 downto 0) := (others=>'0');
signal led         : std_logic_vector(7 downto 0) := (others=>'0');

signal lut_clock     : std_logic := '0';
signal lut_config_in : std_logic := '0';

-- switch(0) = c(0)  - currentSample
-- switch(1) = c(1)  - currentSample
-- switch(2) = c(2)  - lastSample
-- switch(3) = c(3)  - lastSample
-- switch(4) = c(4)  - lut_clock (effective)
-- switch(5) = c(5)  - lut_config_in
-- switch(6) = c(6)  - 
-- switch(7) = c(7)  - 

-- led(0)    = c(8)  - lut_config_out
-- led(1)    = c(9)  - lut_config_ce
-- led(2)    = c(10) -
-- led(3)    = c(11) -
-- led(4)    = c(12) - toggle
-- led(5)    = c(13) - sw(6)
-- led(6)    = c(14) - trigger1
-- led(7)    = c(15) - trigger0

BEGIN

   Wiring:
   process(lut_clock, lut_config_in, reset)
   begin
      switch <= (others => '0');
      switch(4) <= lut_clock;
      switch(5) <= lut_config_in;
   end process;
   
   TestModule_uut:
   entity work.TestModule 
      port map ( 
         reset       => reset,    
         clock       => clock,        
         switch      => switch,     
         led         => led        
      );

   -- clock process definitions
   clock_process :
   process
   begin
      while not complete loop
         clock <= '1';
         wait for CLOCK_PERIOD/2;
         clock <= '0';
         wait for CLOCK_PERIOD/2;
      end loop;
      -- kill clock
      wait;
   end process; 

   -- Stimulus process
   stim_proc: 
   process
    
   procedure writeLut(data: std_logic_vector(31 downto 0)) is
   begin
--      lut_config_ce <= '1';
      for ticks in data'left downto data'right loop
         lut_config_in <= data(ticks);
         wait for 100 us;
         lut_clock <= '1';
         wait for 100 us;
         lut_clock <= '0';
      end loop;
--      lut_config_ce <= '0';
   end procedure;
   
   type StimulusArray is array (0 to 20) of std_logic_vector(31 downto 0);
   variable stimulus : StimulusArray := (
      x"FFFFFFFF", x"FFFFFFFF", x"FFFFFFFF", x"FFFFFFFF",
      x"AAAAAAAA", x"AAAAAAAA", x"AAAAAAAA", x"AAAAAAAA",
      x"22222222", x"22222222", x"22222222", x"22222222",
      x"44444444", x"44444444", x"44444444", x"44444444",
      others => (x"00000000")
   );

   begin
      reset <= '1';
      wait for 10 * CLOCK_PERIOD;
      reset <= '0';
   
      wait until falling_edge(clock);
      wait until falling_edge(clock);
      wait for 20 ns;
      
      for match in 0 to 3 loop
         for index in 0 to 3 loop
            writeLut(stimulus(match*4+index));
         end loop;
      end loop;
      
      complete <= true;
      wait for 20 ns;
      
      -- Kill stimulus
      wait;
   end process;


END;
