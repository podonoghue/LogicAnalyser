library ieee;
use ieee.std_logic_1164.all;
 
entity Prescaler_tb is
end Prescaler_tb;
 
architecture behavior of Prescaler_tb is 
 
   signal clock_100MHz          : std_logic := '0';
   signal enable                : std_logic := '0';
   signal selectDivider         : std_logic_vector(1 downto 0) := (others => '0');
   signal selectDecade          : std_logic_vector(1 downto 0);
   signal doSample              : std_logic := '0';

   -- clock period definitions
   constant clock_100MHz_period : time := 10 ns;
 
   signal complete : boolean    := false;
   
   signal counter : natural     := 0;
      
   constant div_1     : std_logic_vector(1 downto 0) := "00";
   constant div_2     : std_logic_vector(1 downto 0) := "01";
   constant div_5     : std_logic_vector(1 downto 0) := "10";
   constant div_10    : std_logic_vector(1 downto 0) := "11";
   
   constant div_x1    : std_logic_vector(1 downto 0) := "00";
   constant div_x10   : std_logic_vector(1 downto 0) := "01";
   constant div_x100  : std_logic_vector(1 downto 0) := "10";
   constant div_x1000 : std_logic_vector(1 downto 0) := "11";
   
begin
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity 
   work.Prescaler 
   port map (
          clock_100MHz         => clock_100MHz,
          enable               => enable,
          selectDivider        => selectDivider,
          selectDecade         => selectDecade,
          doSample             => doSample
        );

   -- clock process definitions
   clock_100MHz_process :process
   begin
      while not complete loop
         clock_100MHz <= '0';
         wait for clock_100MHz_period/2;
         clock_100MHz <= '1';
         wait for clock_100MHz_period/2;
      end loop;
      wait;
   end process;

   process(clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         if (doSample = '1') then
            counter <= counter + 1;
         end if;
      end if;
   end process;
   
   monitorProc:
   process
   begin
      while not complete loop
         wait until doSample'event;
         report "Interval = " & integer'image(doSample'delayed'last_event / (1 ns));
      end loop;
   end process;
   
   -- Stimulus process
   stim_proc: process
   
   variable delay : time;

   type StimulusArray is array (0 to 3) of std_logic_vector(1 downto 0);
   
   variable dec : StimulusArray := (div_x1, div_x10, div_x100, div_x1000);
   variable div : StimulusArray := (div_1,  div_2,   div_5,    div_10);

   begin		
      wait for 2 * clock_100MHz_period;

      enable <= '1';
      
      delay := clock_100MHz_period*4;

      for index1 in 0 to 3 loop
         selectDecade <= dec(index1);
         
         selectDivider <= div_1;
         delay := delay * 1;
         wait for delay;
         enable <= '0';
         wait for delay;
         enable <= '1';
         
         selectDivider <= div_2;
         delay := delay * 2;
         wait for delay;
         enable <= '0';
         wait for delay;
         enable <= '1';

         selectDivider <= div_5;
         delay := delay * 2.5;
         wait for delay;
         enable <= '0';
         wait for delay;
         enable <= '1';

         --selectDivider <= div_10;
         delay := delay * 2;
         --wait for delay;

      end loop;

      selectDivider <= div_10;
      wait for delay;
      enable <= '0';
      wait for delay;
      enable <= '1';
      
      complete <= true;
      
      wait;
   end process;

end;
