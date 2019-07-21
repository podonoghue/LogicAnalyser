LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

ENTITY LogicAnalyser_tb IS
END entity;
 
ARCHITECTURE behavior OF LogicAnalyser_tb IS 
 
   --Inputs
   signal reset            : std_logic       := '0';
   signal clock_100MHz     : std_logic       := '0';
   signal clock_100MHz_n   : std_logic       := '0';
   signal clock_200MHz     : std_logic       := '0';
                                             
	-- FT2232H Interface                      
   signal ft2232h_rxf_n    : std_logic       := '1';
   signal ft2232h_txe_n    : std_logic       := '1';
   signal ft2232h_rd_n     : std_logic       := '0';
   signal ft2232h_wr       : std_logic       := '0';
   signal ft2232h_data     : DataBusType     := (others => 'Z');

   signal enable           : std_logic       := '0';
   signal sample           : SampleDataType  := (others => '0');   
   
   -- Clock period definitions
   constant clock_period  : time             := 5 ns;
   signal   complete      : boolean          := false;

   signal write_data      : DataBusType      := (others => '0');
   signal write_data_req  : std_logic        := '0';

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   LogicAnalyser_uut:
   entity work.LogicAnalyser 
   PORT MAP (
      reset                 => reset,
      clock_100MHz          => clock_100MHz,
      clock_100MHz_         => clock_100MHz_n,
      clock_200MHz          => clock_200MHz,
      
      -- FT2232H Interface
      ft2232h_rxf_n         => ft2232h_rxf_n,
      ft2232h_txe_n         => ft2232h_txe_n,
      ft2232h_rd_n          => ft2232h_rd_n,
      ft2232h_wr            => ft2232h_wr,
      ft2232h_data          => ft2232h_data,
      
      enable                => enable,
      sample                => sample,
      
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
   
   -- Stimulus process
   stim_proc: process
   
   procedure writeLut(addrIn : AddressBusType; data : DataBusType) is
   begin
      ft2232h_wr     <= '1';
      addr   <= addrIn;
      dataIn <= data;
      wait for 0.1*clock_period;
      wait until rising_edge(clock);
      wait for 0.1*clock_period;
      ft2232h_wr     <= '0';
      wait for 12.4*clock_period;
   end procedure;
   
   type StiumulusEntry is record
      addr : AddressBusType;
      data0 : DataBusType;
      data1 : DataBusType;
      data2 : DataBusType;
      data3 : DataBusType;
   end record;
  
  -- And   T0[XX, Normal  ] T1[XX, Disabled] Count = 4
  -- And   T0[X0, Normal  ] T1[X0, Disabled] Count = 3
  -- And   T0[X1, Normal  ] T1[X1, Disabled] Count = 2
  -- And   T0[XC, Normal  ] T1[XC, Disabled] Count = 7

   constant SIM_SAMPLE_WIDTH           : natural := 2;
   constant SIM_MAX_TRIGGER_STEPS      : natural := 4;
   constant SIM_MAX_TRIGGER_PATTERNS   : natural := 2;
   constant SIM_NUM_TRIGGER_FLAGS      : natural := 2;
   constant SIM_NUM_MATCH_COUNTER_BITS : natural := 16;

   type StimulusArray is array (0 to 25) of StiumulusEntry;
   variable stimulus : StimulusArray := (
      -- PatternMatcher LUT values
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "01100110", "01100110", "01100110", "01100110" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "10101010", "10101010", "10101010", "10101010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "01010101", "01010101", "01010101", "01010101" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "11111111", "11111111", "11111111", "11111111" ),
      -- Combiner LUT values
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001010" ),
      -- Count LUT values
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000100" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000101" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000110" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000011" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001101" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000010" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001001" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" ),
      -- Flag LUT values
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00001000" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), "00000000", "00000000", "00000000", "00000000" )
   );
   
   procedure writeAllLuts is
   begin

      assert (SIM_SAMPLE_WIDTH            = SAMPLE_WIDTH) report           "SAMPLE_WIDTH wrong";
      assert (SIM_MAX_TRIGGER_STEPS       = MAX_TRIGGER_STEPS) report      "MAX_TRIGGER_STEPS wrong";
      assert (SIM_MAX_TRIGGER_PATTERNS    = MAX_TRIGGER_PATTERNS) report   "MAX_TRIGGER_PATTERNS wrong";
      assert (SIM_NUM_TRIGGER_FLAGS       = NUM_TRIGGER_FLAGS) report      "NUM_TRIGGER_FLAGS wrong";
      assert (SIM_NUM_MATCH_COUNTER_BITS  = NUM_MATCH_COUNTER_BITS) report "NUM_MATCH_COUNTER_BITS wrong";

      for index in 0 to stimulus'length-1 loop
         writeLut(stimulus(index).addr, stimulus(index).data0);
         writeLut(stimulus(index).addr, stimulus(index).data1);
         writeLut(stimulus(index).addr, stimulus(index).data2);
         writeLut(stimulus(index).addr, stimulus(index).data3);
      end loop;
   end procedure;

   begin	
      reset <= '1';
      wait for clock_period*10;
      reset <= '0';
      wait for clock_period;

      writeAllLuts;
      writeAllLuts;
      
      wait until falling_edge(clock);
      sample  <= "11";  wait for clock_period * 5;

      enable  <= '1';
      sample  <= "11";  wait for clock_period * 5;
      sample  <= "00";  wait for clock_period * 5;
      sample  <= "01";  wait for clock_period * 5;
      sample  <= "00";  wait for clock_period * 5;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      sample  <= "01";  wait for clock_period * 2;
      sample  <= "00";  wait for clock_period * 2;
      
      wait for clock_period * 20;
      
      complete <= true;
      wait for 10 ns;
      wait;
      
   end process;

END;