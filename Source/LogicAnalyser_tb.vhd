LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

ENTITY LogicAnalyser_tb IS
END entity;
 
ARCHITECTURE behavior OF LogicAnalyser_tb IS 
 
   --Inputs
   signal   reset                 : std_logic       := '1';
   signal   clock_100MHz          : std_logic       := '0';
   signal   clock_100MHz_n        : std_logic       := '1';
   signal   clock_200MHz          : std_logic       := '0';
                                                  
	-- FT2232H Interface                           
   signal   ft2232h_rxf_n         : std_logic       := '1';
   signal   ft2232h_txe_n         : std_logic       := '1';
   signal   ft2232h_rd_n          : std_logic       := '1';
   signal   ft2232h_wr_n          : std_logic       := '1';
   signal   ft2232h_data          : DataBusType     := (others => 'Z');
                                  
   signal   armed_o               : std_logic;
   signal   sample                : SampleDataType  := (others => '0');   
   signal   sampleEnable          : std_logic;
   
   signal   initializing        : std_logic;
   signal   sdram_clk           : std_logic;
   signal   sdram_cke           : std_logic;
   signal   sdram_cs_n          : std_logic;
   signal   sdram_ras_n         : std_logic;
   signal   sdram_cas_n         : std_logic;
   signal   sdram_we_n          : std_logic;
   signal   sdram_dqm           : std_logic_vector( 1 downto 0);
   signal   sdram_addr          : std_logic_vector(12 downto 0);
   signal   sdram_ba            : std_logic_vector( 1 downto 0);
   signal   sdram_data          : std_logic_vector(15 downto 0) := (others => 'Z');

   -- Clock period definitions
   constant clock_period        : time    := 5 ns;
   signal   complete            : boolean := false;
   signal   writeLutsComplete   : boolean := false;

   signal   status : string(1 to 6);
   
begin
 
   sdram_entity:
   entity work.sdram
   port map (
      sdram_clk       => sdram_clk,
      sdram_cke       => sdram_cke,
      sdram_cs_n      => sdram_cs_n,
      sdram_ras_n     => sdram_ras_n,
      sdram_cas_n     => sdram_cas_n,
      sdram_we_n      => sdram_we_n,
      sdram_ba        => sdram_ba,
      sdram_dqm       => sdram_dqm,
      sdram_addr      => sdram_addr,
      sdram_data      => sdram_data
   );

	-- Instantiate the Unit Under Test (UUT)
   LogicAnalyser_uut:
   entity work.LogicAnalyser 
   port map (
      reset           => reset,
      clock_100MHz    => clock_100MHz,
      clock_100MHz_n  => clock_100MHz_n,
      clock_200MHz    => clock_200MHz,
                      
      -- FT2232H      
      ft2232h_rxf_n   => ft2232h_rxf_n,
      ft2232h_txe_n   => ft2232h_txe_n,
      ft2232h_rd_n    => ft2232h_rd_n,
      ft2232h_wr_n    => ft2232h_wr_n,
      ft2232h_data    => ft2232h_data,
                      
      sample          => sample,
      armed_o         => armed_o,
      sampleEnable_o  => sampleEnable,
      
      -- SDRAM        
      initializing    => initializing,
                      
      sdram_clk       => sdram_clk,
      sdram_cke       => sdram_cke,
      sdram_cs_n      => sdram_cs_n,
      sdram_ras_n     => sdram_ras_n,
      sdram_cas_n     => sdram_cas_n,
      sdram_we_n      => sdram_we_n,
      sdram_ba        => sdram_ba,
      sdram_dqm       => sdram_dqm,
      sdram_addr      => sdram_addr,
      sdram_data      => sdram_data
   );

   -- clock process definitions
   clock_200MHz_process :
   process
   begin
      while not complete loop
         clock_200MHz <= '1';
         wait for clock_period/2;
         clock_200MHz <= '0';
         wait for clock_period/2;
      end loop;
      -- kill clock
      wait;
   end process; 
   
   clock_100MHz_process :
   process
   begin
      while not complete loop
         clock_100MHz   <= '1';
         clock_100MHz_n <= '0';
         wait for clock_period;
         clock_100MHz   <= '0';
         clock_100MHz_n <= '1';
         wait for clock_period;
      end loop;
      -- kill clock
      wait;
   end process; 
   
   -- Stimulus processes
   MiscProc:
   process
   begin
      reset <= '1';
      wait for 5 * clock_period;
      reset <= '0';
      wait;
   end process;
   
   -- FT2232 -> Host
   LoadLuts: 
   process
   procedure sendToAnalyser( wr_data : DataBusType) is

   constant t1    : time := 14 ns;
   constant t2    : time := 49 ns;
   constant t3min : time :=  1 ns;
   constant t3max : time := 14 ns;
   constant t4    : time := 30 ns;
   constant t5    : time :=  0 ns;
       
   begin
      assert (ft2232h_rd_n = '1') report "ft2232h_rd_n should be 0";
      ft2232h_rxf_n <= '0';
      wait until ft2232h_rd_n = '0';
      --assert ft2232h_rd_n'delayed'stable(t5) report "ft2232h_rd_n t5 failed";
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= wr_data after t3max;     
      wait until ft2232h_rd_n = '1';
      --assert ft2232h_rd_n'delayed'stable(t4) report "ft2232h_rd_n t4 failed";
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= (others => 'Z') after t3max;     
      ft2232h_rxf_n <= '1' after t1;
      wait for (t1 + t2);
      
--      wait for 40 ns;
   end procedure;
   
   procedure receiveFromAnalyser(rd_data : out DataBusType) is

   constant t6  : time := 14 ns;
   constant t7  : time := 49 ns;
   constant t8  : time :=  5 ns;
   constant t9  : time :=  5 ns;
   constant t10 : time := 30 ns;
   constant t11 : time :=  0 ns;

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
      if (ft2232h_wr_n = '0') then
         wait until ft2232h_wr_n = '1';
      end if;
      if (t7>ft2232h_txe_n'last_active) then
         wait for t7-ft2232h_txe_n'last_active;
      end if;
      --wait for 100 ns;
   end procedure;
   

  -- And   T0[XXXXXXXXXXXXXXXX, Normal  ] T1[XXXXXXXXXXXXXXXX, Disabled] Count = 4
  -- And   T0[XXXXXXXXXXXXXXX0, Normal  ] T1[XXXXXXXXXXXXXXX0, Disabled] Count = 3
  -- And   T0[XXXXXXXXXXXXXXX1, Normal  ] T1[XXXXXXXXXXXXXXX1, Disabled] Count = 2
  -- And   T0[XXXXXXXXXXXXXXXC, Normal  ] T1[XXXXXXXXXXXXXXXC, Disabled] Count = 7

   constant SIM_SAMPLE_WIDTH           : natural := 16;
   constant SIM_MAX_TRIGGER_STEPS      : natural := 4;
   constant SIM_MAX_TRIGGER_PATTERNS   : natural := 2;
   constant SIM_NUM_TRIGGER_FLAGS      : natural := 2;
   constant SIM_NUM_MATCH_COUNTER_BITS : natural := 16;

   type StimulusArray is array (0 to 217) of DataBusType;
   variable stimulus : StimulusArray := (
      -- Preamble 
      C_LUT_CONFIG, "11011000",
      -- PatternMatcher LUT values
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "01100110", "01100110", "01100110", "01100110",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "10101010", "10101010", "10101010", "10101010",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "01010101", "01010101", "01010101", "01010101",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      -- Combiner LUT values
      "00000000", "00000000", "00000000", "00001010",
      "00000000", "00000000", "00000000", "00001010",
      "00000000", "00000000", "00000000", "00001010",
      "00000000", "00000000", "00000000", "00001010",
      -- Count LUT values
      "00000000", "00000000", "00000000", "00000100",
      "00000000", "00000000", "00000000", "00000010",
      "00000000", "00000000", "00000000", "00000101",
      "00000000", "00000000", "00000000", "00000110",
      "00000000", "00000000", "00000000", "00000011",
      "00000000", "00000000", "00000000", "00001101",
      "00000000", "00000000", "00000000", "00000010",
      "00000000", "00000000", "00000000", "00001001",
      "00000000", "00000000", "00000000", "00001000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00001000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      -- Flag LUT values
      "00000000", "00000000", "00000000", "00001000",
      "00000000", "00000000", "00000000", "00000000"
--      "00000000", "00000000", "00000000", "00000000",
--      C_WR_CONTROL, "00000001", "00000001", "00000000"
   );
   
   variable receiveData : DataBusType;
   
   begin
      status <= "Reset ";
   
      if (reset = '1') then
         wait until (reset = '0');
      end if;  
      wait for 60 ns;
      
      status <= "LUTs  ";
      for index in stimulus'range loop
         sendToAnalyser(stimulus(index));
      end loop;

      status <= "Init  ";
      if (initializing = '1') then
         wait until (initializing = '0');
      end if;
      
      status <= "Read20";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(20, 8)));
      
      status <= "Data20";
      for index in 1 to 2*20 loop
         receiveFromAnalyser(receiveData);
      end loop;

      status <= "ClrCnt";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser(C_CONTROL_CLEAR_COUNTS);

      status <= "Idle  ";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser("00000000");

      status <= "Read20";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(20, 8)));
      
      for index in 1 to 2*20 loop
         receiveFromAnalyser(receiveData);
      end loop;

      status <= "Spd50n";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser(C_CONTROL_S_50ns);

      status <= "Enable";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser(C_CONTROL_ENABLE or C_CONTROL_S_50ns);

      status <= "Done  ";
      writeLutsComplete <= true;
      wait;
   end process;

   WaveformProc:
   Process
   type StimulusArray is array (0 to 60) of SampleDataType;
   variable stimulus : StimulusArray := (
   --  111111
   --  5432109876543210
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      "1111111111111111", 
      "1111111111111110", 
      others => x"0000"
   );
   
   begin
      if (reset = '1') then
         wait until (reset = '0');
      end if;         

      wait until armed_o = '1';
      
      wait until falling_edge(clock_100MHz);
      for index in stimulus'range loop
         sample <= stimulus(index);
         wait until (sampleEnable = '1') and falling_edge(clock_100MHz);
      end loop;
      
      wait for 1000 ns;
      complete <= true;
      
      wait;
   end process;
   
END;
