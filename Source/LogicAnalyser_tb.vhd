LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

ENTITY LogicAnalyser_tb IS
END entity;
 
ARCHITECTURE behavior OF LogicAnalyser_tb IS 
 
   --Inputs
   signal reset            : std_logic       := '1';
   signal clock_100MHz     : std_logic       := '0';
   signal clock_100MHz_n   : std_logic       := '1';
   signal clock_200MHz     : std_logic       := '0';
                                             
	-- FT2232H Interface                      
   signal ft2232h_rxf_n    : std_logic       := '1';
   signal ft2232h_txe_n    : std_logic       := '1';
   signal ft2232h_rd_n     : std_logic       := '1';
   signal ft2232h_wr_n       : std_logic     := '1';
   signal ft2232h_data     : DataBusType     := (others => 'Z');

   signal enable           : std_logic       := '0';
   signal sample           : SampleDataType  := (others => '0');   
   
   -- Clock period definitions
   constant clock_period  : time             := 5 ns;
   signal   complete      : boolean          := false;

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   LogicAnalyser_uut:
   entity work.LogicAnalyser 
   PORT MAP (
      reset                 => reset,
      clock_100MHz          => clock_100MHz,
      clock_100MHz_n        => clock_100MHz_n,
      clock_200MHz          => clock_200MHz,
      
      -- FT2232H Interface
      ft2232h_rxf_n         => ft2232h_rxf_n,
      ft2232h_txe_n         => ft2232h_txe_n,
      ft2232h_rd_n          => ft2232h_rd_n,
      ft2232h_wr_n          => ft2232h_wr_n,
      ft2232h_data          => ft2232h_data,
      
      enable                => enable,
      sample                => sample,
      triggerFound          => open,
      
      -- SDRAM
      sdram_clk             => open,
      sdram_cke             => open,     
      sdram_cs              => open,
      sdram_ras_n           => open,
      sdram_cas_n           => open,
      sdram_we_n            => open,
      sdram_dqm             => open,
      sdram_addr            => open,
      sdram_ba              => open,
      sdram_data            => open
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
         clock_100MHz <= '1';
         wait for clock_period;
         clock_100MHz <= '0';
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
      assert (ft2232h_rd_n = '1') report "ft2232h_rd_n should be 0";
      ft2232h_rxf_n <= '0';
      wait until ft2232h_rd_n = '0';
      assert ft2232h_rd_n'delayed'stable(t5) report "ft2232h_rd_n t5 failed";
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= wr_data after t3max;     
      wait until ft2232h_rd_n = '1';
      assert ft2232h_rd_n'delayed'stable(t4) report "ft2232h_rd_n t4 failed";
      ft2232h_data <= (others => 'X') after t3min;
      ft2232h_data <= (others => 'Z') after t3max;     
      ft2232h_rxf_n <= '1' after t1;
      wait for (t1 + t2);
      
--      wait for 40 ns;
   end procedure;
   
  -- And   T0[XX, Normal  ] T1[XX, Disabled] Count = 4
  -- And   T0[X0, Normal  ] T1[X0, Disabled] Count = 3
  -- And   T0[X1, Normal  ] T1[X1, Disabled] Count = 2
  -- And   T0[XC, Normal  ] T1[XC, Disabled] Count = 7

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
      "01100110", "01100110", "01100110", "01100110",
      "11111111", "11111111", "11111111", "11111111",
      "01000100", "01000100", "01000100", "01000100",
      "11111111", "11111111", "11111111", "11111111",
      "11110000", "11110000", "11110000", "11110000",
      "11111111", "11111111", "11111111", "11111111",
      "00001111", "00001111", "00001111", "00001111",
      "11111111", "11111111", "11111111", "11111111",
      "10101010", "10101010", "10101010", "10101010",
      "11111111", "11111111", "11111111", "11111111",
      "01100110", "01100110", "01100110", "01100110",
      "11111111", "11111111", "11111111", "11111111",
      "01000100", "01000100", "01000100", "01000100",
      "11111111", "11111111", "11111111", "11111111",
      "11110000", "11110000", "11110000", "11110000",
      "11111111", "11111111", "11111111", "11111111",
      "01010101", "01010101", "01010101", "01010101",
      "11111111", "11111111", "11111111", "11111111",
      "10101010", "10101010", "10101010", "10101010",
      "11111111", "11111111", "11111111", "11111111",
      "01100110", "01100110", "01100110", "01100110",
      "11111111", "11111111", "11111111", "11111111",
      "01000100", "01000100", "01000100", "01000100",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "11111111", "11111111", "11111111", "11111111",
      "01010101", "01010101", "01010101", "01010101",
      "11111111", "11111111", "11111111", "11111111",
      "10101010", "10101010", "10101010", "10101010",
      "11111111", "11111111", "11111111", "11111111",
      "01100110", "01100110", "01100110", "01100110",
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
   );


   
   begin
      if (reset = '1') then
         wait until (reset = '0');
      end if;         
      ft2232h_hostRead(C_NOP);
      ft2232h_hostRead(C_NOP);
      for index in stimulus'range loop
         ft2232h_hostRead(stimulus(index));
      end loop;
      ft2232h_hostRead(C_NOP);
      ft2232h_hostRead(C_NOP);
      ft2232h_hostRead(C_NOP);

      complete <= true;
      wait for 10 ns;
      wait;
   end process;

END;
