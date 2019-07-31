library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.logicanalyserpackage.all;
 
entity fifo_tb is
end fifo_tb;
 
architecture behavior of fifo_tb is 
 
   --inputs
   signal clock   : std_logic := '0';
   signal reset   : std_logic := '0';
   signal fifo_wr_en   : std_logic := '0';
   signal fifo_data_in     : SampleDataType := (others => '0');
   signal fifo_rd_en   : std_logic := '0';

 	--outputs
   signal fifo_data_out    : SampleDataType;
   signal fifo_not_empty   : std_logic;
   signal fifo_full        : std_logic;

   -- clock
   constant clock_period   : time    := 10 ns;
   signal   complete       : boolean := false;

begin
 
	-- instantiate the unit under test (uut)
fifo_uut:
   entity fifo 
   port map (
       clock           => clock,
       reset           => reset,
                       
       fifo_full       => fifo_full,
       fifo_wr_en      => fifo_wr_en,
       fifo_data_in    => fifo_data_in,
       
       fifo_not_empty  => fifo_not_empty,
       fifo_rd_en      => fifo_rd_en,
       fifo_data_out   => fifo_data_out
     );

   clock_100MHz_process :
   process
   begin
      while not complete loop
         clock <= '1';
         wait for clock_period/2;
         clock <= '0';
         wait for clock_period/2;
      end loop;
      -- kill clock
      wait;
   end process; 
 
   -- stimulus process
   StimProc: 
   process
   
      variable writeCounter : SampleDataType := std_logic_vector(to_unsigned(10, SampleDataType'length));
      variable stuffRead    : SampleDataType := (others => 'Z');
      
      procedure writeStuff(count : natural) is
      begin
         fifo_wr_en <= '1';
         for index in 0 to count-1 loop
            fifo_data_in <= std_logic_vector(writeCounter);
            wait until falling_edge(clock);
            writeCounter := std_logic_vector(unsigned(writeCounter) + 1);
         end loop;
         fifo_wr_en <= '0';
         wait for 2* clock_period;
      end procedure;
      
      procedure readStuff(count : natural) is
      begin
         fifo_rd_en <= '1';
         for index in 0 to count-1 loop
            wait until rising_edge(clock);
            wait for 0 ns;
            stuffRead := fifo_data_out;
         end loop;
         fifo_rd_en <= '0';
         wait for 2* clock_period;
      end procedure;
      
   begin		
      reset <= '1';
      wait for 2 * clock_period;	
      reset <= '0';
      wait until falling_edge(clock);
      wait for 0.5 ns;
      
      writeStuff(5);
      assert (fifo_not_empty = '1');
      readStuff(4);
      
      writeStuff(15);
      assert (fifo_full = '1');
      assert (fifo_not_empty = '1');
      readStuff(16);
      assert (fifo_full = '0');
      assert (fifo_not_empty = '0');
      
      wait for 100 ns;
      complete <= true;
      
      wait;
   end process;

end;
