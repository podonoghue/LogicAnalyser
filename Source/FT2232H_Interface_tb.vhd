LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

use work.all;
use work.LogicAnalyserPackage.all;
 
ENTITY ft2232h_Interface_tb IS
END ft2232h_Interface_tb;
 
ARCHITECTURE behavior OF ft2232h_Interface_tb IS 
 
   --Inputs
   signal reset            : std_logic := '0';
   signal clock_100MHz     : std_logic := '0';
   signal ft2232h_rxf_n    : std_logic := '1';
   signal ft2232h_txe_n    : std_logic := '1';
   signal write_data       : DataBusType := (others => '0');
   signal write_data_req   : std_logic := '0';

	--BiDirs
   signal ft2232h_data : DataBusType := (others => 'Z');

 	--Outputs
   signal ft2232h_rd_n     : std_logic;
   signal ft2232h_wr       : std_logic;
   signal receive_data     : DataBusType;
   signal receive_data_st  : std_logic;

   -- Clock period definitions
   constant clock_period   : time    := 10 ns;
   signal   complete1      : boolean := false;
   signal   complete2      : boolean := false;

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut:
   entity work.ft2232h_Interface 
   PORT MAP (
      reset            => reset,
      clock_100MHz     => clock_100MHz,
      ft2232h_rxf_n    => ft2232h_rxf_n,
      ft2232h_txe_n    => ft2232h_txe_n,
      ft2232h_rd_n     => ft2232h_rd_n,
      ft2232h_wr       => ft2232h_wr,
      ft2232h_data     => ft2232h_data,
      receive_data     => receive_data,
      receive_data_st  => receive_data_st,
      write_data       => write_data,
      write_data_req   => write_data_req
   );

   -- clock process definitions
   clock_process :
   process
   begin
      while not (complete1 and complete2) loop
         clock_100MHz <= '1';
         wait for clock_period/2;
         clock_100MHz <= '0';
         wait for clock_period/2;
      end loop;
      -- kill clock
      wait;
   end process; 
   
   ResetProc:
   process
   begin
      -- hold reset state for 100 ns.
      reset <= '1';
      wait for 2 * clock_period;	
      reset <= '0';
      wait;
   end process;
   
   -- Stimulus process
   WriteProc: 
   process
   
   procedure writeValue( wr_data : DataBusType) is
   begin
      ft2232h_rxf_n <= '0';
      if (ft2232h_rd_n /= '0') then
         wait until ft2232h_rd_n = '0';
      end if;
      wait for 50 ns;
      ft2232h_data <= wr_data;
      wait until ft2232h_rd_n = '1';
      ft2232h_data <= (others => 'Z');
      wait for 10 ns;
      ft2232h_rxf_n <= '1';
      wait for 40 ns;
   end procedure;
   
   begin		
      writeValue(x"AA");
      writeValue(x"BB");
      wait for 100 ns;
      writeValue(x"CC");
      writeValue(x"DD");

      complete1 <= true;
      wait for 10 ns;
      wait;
   end process;

   -- Stimulus process
   ReadProc: 
   process
   
   procedure readValue(rd_data : out DataBusType) is
   begin
      ft2232h_txe_n <= '0';
      if (ft2232h_wr /= '1') then
         wait until ft2232h_wr = '1';
      end if;
      wait until ft2232h_wr = '0';
      rd_data := ft2232h_data;
      wait for 25 ns;
      ft2232h_txe_n <= '1';
      wait for 100 ns;
   end procedure;
   
   variable rdData : DataBusType;
   
   begin		
      wait for 150 ns;
      write_data_req <= '1';
      readValue(rdData);
      readValue(rdData);
      readValue(rdData);
      readValue(rdData);

      complete2 <= true;
      wait for 10 ns;
      wait;
   end process;

END;
