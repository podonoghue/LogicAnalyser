library ieee;
use ieee.std_logic_1164.all;
 
entity clockdivider_tb is
end clockdivider_tb;
 
architecture behavior of clockdivider_tb is 
 
   signal reset                : std_logic := '0';
   signal clock_100MHz         : std_logic := '0';
   signal enable               : std_logic := '0';
   signal clockDiv_10_Value    : std_logic_vector(3 downto 0) := (others => '0');
   signal clockDiv_1_2_5_Value : std_logic_vector(1 downto 0) := (others => '0');

 	--Outputs
   signal sampleEnable : std_logic;

   -- clock period definitions
   constant clock_100MHz_period : time := 10 ns;
 
   signal complete : boolean := false;
   
   signal counter : natural := 0;
   
begin
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity 
   work.clockDivider 
   port map (
          reset                => reset,
          clock_100MHz         => clock_100MHz,
          enable               => enable,
          sampleEnable         => sampleEnable,
          clockDiv_10_Value    => clockDiv_10_Value,
          clockDiv_1_2_5_Value => clockDiv_1_2_5_Value
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
         if (reset = '1') then
            counter <= 0;
         elsif (sampleEnable = '1') then
            counter <= counter + 1;
         end if;
      end if;
   end process;
   
   -- Stimulus process
   stim_proc: process
   begin		
      reset <= '1';
      wait for 2 * clock_100MHz_period;
      reset <= '0';

      enable <= '1';
      
      clockDiv_10_Value <= "1000";
      
      clockDiv_1_2_5_Value <= "00";
      wait for clock_100MHz_period*5;

      clockDiv_1_2_5_Value <= "01";
      wait for clock_100MHz_period*10;

      clockDiv_1_2_5_Value <= "10";
      wait for clock_100MHz_period*20;

      clockDiv_1_2_5_Value <= "11";
      wait for clock_100MHz_period*40;

      complete <= true;
      wait for 10 ns;
      -- counter <= 3;
      
      wait;
   end process;

end;
