LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
use work.logicanalyserpackage.all;

ENTITY fifo_2clock_tb IS
END fifo_2clock_tb;
 
ARCHITECTURE behavior OF fifo_2clock_tb IS 
 
   --Inputs
   signal w_clock    : std_logic := '0';
   signal w_enable   : std_logic := '0';
   signal w_clear    : std_logic := '0';
   signal w_data     : sampledatatype := (others => '0');
   signal r_clock    : std_logic := '0';
   signal r_clear    : std_logic := '0';
   signal r_enable   : std_logic := '0';

 	--Outputs
   signal w_isFull   : std_logic;
   signal r_isEmpty  : std_logic;
   signal r_data     : sampledatatype;

   -- Clock period definitions
   constant w_clock_period : time := 10 ns;
   constant r_clock_period : time := 7 ns;
 
   signal complete : boolean := false;
   signal refresh  : std_logic := '0';
   
   signal stuffRead     : SampleDataType := (others => '0');
   signal lastStuffRead : SampleDataType := (others => '0');

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   fifo_2clock_uut:
   entity work.fifo_2clock 
   PORT MAP (
          w_clock    => w_clock,
          w_enable   => w_enable,
          w_clear    => w_clear,
          w_isFull   => w_isFull,
          w_data     => w_data,
          r_clock    => r_clock,
          r_clear    => r_clear,
          r_enable   => r_enable,
          r_isEmpty  => r_isEmpty,
          r_data     => r_data
        );

   -- Clock process definitions
   w_clock_process :process
   begin
      while not complete loop
         w_clock <= '0';
         wait for w_clock_period/2;
         w_clock <= '1';
         wait for w_clock_period/2;
      end loop;
      wait;
   end process;
 
   r_clock_process :process
   begin
      while not complete loop
         r_clock <= '0';
         wait for r_clock_period/2;
         r_clock <= '1';
         wait for r_clock_period/2;
      end loop;
      wait;
   end process;

   refreshProc:
   process
   begin
      while not complete loop
         wait for 8 us;
         refresh <= '1';
         wait for 16 * 10 ns;
         refresh <= '0';
      end loop;
      wait;
   end process;
   
   read_proc: 
   -- Stimulus process
   process(r_clock, r_isEmpty, refresh)
   
   variable dataAvailable :std_logic := '0';
   variable startUpCount : natural := 0;
   
   begin
      if (startUpCount<100) then
         startUpCount := startUpCount + 1;
      else
         r_enable <= not r_isEmpty and not refresh;
      end if;
      if rising_edge(r_clock) then
         if (dataAvailable = '1') then
            lastStuffRead <= stuffRead;
            stuffRead     <= r_data;
            if (lastStuffRead /= "XXXX") and (stuffRead /= "XXXX")  then
               assert (unsigned(lastStuffRead)+1 = unsigned(stuffRead));
            end if;
         end if;
         dataAvailable := r_enable;
      end if;
   end process;
   
--   Stimulus process
   -- read_proc: 
   -- process
      -- variable stuffRead    : SampleDataType := (others => 'Z');
   
      -- procedure readStuff(count : natural) is
      -- begin
         -- r_enable <= '1';
         -- for index in 0 to count-1 loop
            -- if (r_clock = '1') then
              -- wait until falling_edge(r_clock);
            -- end if;
            -- wait until rising_edge(r_clock);
            -- wait for 0 ns;
            -- stuffRead := r_data;
         -- end loop;
         -- r_enable <= '0';
      -- end procedure;

   -- begin		

      -- wait for 10 * w_clock_period;
      -- readStuff(16);
      -- while r_isEmpty loop
      -- end loop;
      -- readStuff(4);
      
      -- complete <= true;

      -- wait;
   -- end process;

   -- Stimulus process
   write_proc: 
   process
   
      variable writeCounter : SampleDataType := std_logic_vector(to_unsigned(32, SampleDataType'length));

      procedure writeStuff(count : natural) is
      begin
         
         w_enable <= '1';
         for index in 0 to count-1 loop
            if (w_clock = '1') then
              wait until falling_edge(w_clock);
            end if;
            wait for 1 ns;
            w_data <= std_logic_vector(writeCounter);
            wait until falling_edge(w_clock);
            writeCounter := std_logic_vector(unsigned(writeCounter) + 1);
         end loop;
         w_enable <= '0';
      end procedure;
   
   begin		

      for index in 0 to 10 loop
         writeStuff(1000);
         wait for 10 * w_clock_period;
      end loop;
      
      if (r_isEmpty = '0') then
         wait until r_isEmpty = '1';
      end if;
      
      wait for 100 ns;
      complete <= true;

      wait;
   end process;

END;
