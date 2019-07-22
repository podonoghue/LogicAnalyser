LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

use work.all;
use work.LogicAnalyserPackage.all;
 
ENTITY ft2232h_Interface_tb IS
END ft2232h_Interface_tb;
 
ARCHITECTURE behavior OF ft2232h_Interface_tb IS 
 
   signal reset              : std_logic := '0';
   signal clock_100MHz       : std_logic := '0';
   
   signal ft2232h_rxf_n      : std_logic := '1';
   signal ft2232h_rd_n       : std_logic;   
   signal ft2232h_txe_n      : std_logic := '1';
   signal ft2232h_wr_n       : std_logic;
   signal ft2232h_data       : DataBusType := (others => 'Z');

   signal receive_data       : DataBusType;
   signal receive_data_st    : std_logic;
   signal receive_data_ready : std_logic := '0';
   
   signal send_data          : DataBusType := (others => '0');
   signal send_data_ready    : std_logic;
   signal send_data_req      : std_logic := '0';

   -- Clock period definitions
   constant clock_period   : time    := 10 ns;
   signal   complete1      : boolean := false;
   signal   complete2      : boolean := false;

   
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut:
   entity work.ft2232h_Interface 
   PORT MAP (
      reset                => reset,
      clock_100MHz         => clock_100MHz,
      
      -- FT2232 interface
      ft2232h_rxf_n        => ft2232h_rxf_n,
      ft2232h_rd_n         => ft2232h_rd_n,
      
      ft2232h_txe_n        => ft2232h_txe_n,
      ft2232h_wr_n         => ft2232h_wr_n,

      ft2232h_data         => ft2232h_data,

      -- Receive interface      
      receive_data         => receive_data,
      receive_data_ready   => receive_data_ready,
      receive_data_st      => receive_data_st,
      
      -- Send interface
      send_data            => send_data,
      send_data_ready      => send_data_ready,
      send_data_req        => send_data_req
   );

   -- Clock process definitions
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
      -- Hold reset state for 100 ns.
      reset <= '1';
      wait for 2 * clock_period;	
      reset <= '0';
      wait;
   end process;
   
   -- Stimulus process
   -- FT2232 -> Host
   HostReadProc: 
   process
       constant t1    : time := 14 ns;
       constant t2    : time := 49 ns;
       constant t3min : time :=  1 ns;
       constant t3max : time := 14 ns;
       constant t4    : time := 30 ns;
       constant t5    : time :=  0 ns;
       
   procedure ft2232h_hostRead( wr_data : DataBusType) is
   begin
      assert (ft2232h_rd_n = '1');
      ft2232h_rxf_n <= '0';
      wait until ft2232h_rd_n = '0';
      assert (ft2232h_rd_n'last_active >= t5);
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= wr_data after t3max;     
      wait until ft2232h_rd_n = '1';
      assert (ft2232h_rd_n'last_active >= t4);
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= (others => 'Z') after t3max;     
      ft2232h_rxf_n <= '1' after t1;
      wait for (t1 + t2);
      
      wait for 40 ns;
   end procedure;
   
   begin		
      ft2232h_hostRead(x"AA");
      ft2232h_hostRead(x"BB");
      wait for 100 ns;
      ft2232h_hostRead(x"CC");
      ft2232h_hostRead(x"DD");

      complete1 <= true;
      wait for 10 ns;
      wait;
   end process;

   -- Stimulus process
   -- Host -> FT2232
   HostWriteProc: 
   process
    constant t6  : time := 14 ns;
    constant t7  : time := 49 ns;
    constant t8  : time :=  5 ns;
    constant t9  : time :=  5 ns;
    constant t10 : time := 30 ns;
    constant t11 : time :=  0 ns;
    
   procedure ft2232h_hostWrite(rd_data : out DataBusType) is
   begin
      assert (ft2232h_wr_n = '1');
      ft2232h_txe_n <= '0';
      wait until ft2232h_wr_n = '0';
      assert (ft2232h_data'last_active > t8);
      rd_data := ft2232h_data;
      ft2232h_txe_n <= '1' after t6;
      wait for t9;
      assert (ft2232h_data'last_active >= t8+t9);
      wait for t10-t9;
      assert (ft2232h_wr_n'last_active >= t10);
      wait until ft2232h_wr_n = '1';
      wait for t7+ft2232h_txe_n'last_active;
      
      wait for 100 ns;
   end procedure;
   
   variable rdData : DataBusType;
   
   begin		
      wait for 150 ns;
      send_data_req <= '1';
      send_data     <= x"23";
      ft2232h_hostWrite(rdData);
      receive_data_ready <= '1';
      ft2232h_hostWrite(rdData);
      ft2232h_hostWrite(rdData);
      ft2232h_hostWrite(rdData);

      complete2 <= true;
      wait for 10 ns;
      wait;
   end process;

END;
