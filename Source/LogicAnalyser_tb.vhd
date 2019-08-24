LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

ENTITY LogicAnalyser_tb IS
END entity;
 
ARCHITECTURE behavior OF LogicAnalyser_tb IS 
 
   --Inputs
   signal   clock_100MHz          : std_logic       := '0';
   signal   clock_110MHz          : std_logic       := '0';
   signal   clock_110MHz_n        : std_logic       := '1';
                                                  
	-- FT2232H Interface                           
   signal   ft2232h_rxf_n         : std_logic       := '1';
   signal   ft2232h_txe_n         : std_logic       := '1';
   signal   ft2232h_rd_n          : std_logic       := '1';
   signal   ft2232h_wr_n          : std_logic       := '1';
   signal   ft2232h_data          : DataBusType     := (others => 'Z');
                                  
   signal   armed               : std_logic;
   signal   sampling            : std_logic;
   signal   sample              : SampleDataType  := (others => '0');   
   signal   doSample            : std_logic;

   signal   initializing        : std_logic;
   signal   sdram_clk           : std_logic;
   signal   sdram_cke           : std_logic;
   signal   sdram_cs_n          : std_logic;
   signal   sdram_ras_n         : std_logic;
   signal   sdram_cas_n         : std_logic;
   signal   sdram_we_n          : std_logic;
   signal   sdram_dqm           : std_logic_vector( 1 downto 0) := (others => '0');
   signal   sdram_addr          : std_logic_vector(12 downto 0) := (others => '0');
   signal   sdram_ba            : std_logic_vector( 1 downto 0) := (others => '0');
   signal   sdram_data          : std_logic_vector(15 downto 0) := (others => 'Z');

   -- Clock period definitions
   constant clock100MHz_period  : time    := 10 ns;
   constant clock110MHz_period  : time    :=  9 ns; -- 110 MHz
   signal   complete            : boolean := false;
--   signal   writeLutsComplete   : boolean := false;

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
      clock_100MHz    => clock_100MHz,
      clock_110MHz    => clock_110MHz,
      clock_110MHz_n  => clock_110MHz_n,
                      
      -- FT2232H      
      ft2232h_rxf_n   => ft2232h_rxf_n,
      ft2232h_txe_n   => ft2232h_txe_n,
      ft2232h_rd_n    => ft2232h_rd_n,
      ft2232h_wr_n    => ft2232h_wr_n,
      ft2232h_data    => ft2232h_data,
                      
      sample          => sample,
      armed_o         => armed,
      sampling_o      => sampling,
      doSample_o      => doSample,
      
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
   clock_100MHz_process :
   process
   begin
      while not complete loop
         clock_100MHz <= '1';
         wait for clock100MHz_period/2;
         clock_100MHz <= '0';
         wait for clock100MHz_period/2;
      end loop;
      -- kill clock
      wait;
   end process; 
   
   clock_110MHz_process :
   process
   begin
      while not complete loop
         clock_110MHz   <= '1';
         clock_110MHz_n <= '0';
         wait for clock110MHz_period/2;
         clock_110MHz   <= '0';
         clock_110MHz_n <= '1';
         wait for clock110MHz_period/2;
      end loop;
      -- kill clock
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
      report "Sample = 0b" & to_string(rd_data);
   end procedure;

-- Or (T0[0111111111111111, Normal  ] T1[0111111111111110, Normal  ] ), Count = 1

   constant SIM_SAMPLE_WIDTH           : natural := 16;
   constant SIM_MAX_TRIGGER_STEPS      : natural := 16;
   constant SIM_MAX_TRIGGER_PATTERNS   : natural := 2;
   constant SIM_NUM_TRIGGER_FLAGS      : natural := 2;
   constant SIM_NUM_MATCH_COUNTER_BITS : natural := 16;
   constant SIM_NUM_STIMULUS           : natural := 648;
   constant SIM_NUM_PATTERN_STIMULUS   : natural := 512;
   constant SIM_NUM_COMBINER_STIMULUS  : natural := 64;
   constant SIM_NUM_COUNT_STIMULUS     : natural := 64;
   constant SIM_NUM_FLAG_STIMULUS      : natural := 8;

   type StimulusArray is array (0 to 647) of DataBusType;
   variable stimulus : StimulusArray := (
      -- PatternMatcher LUT values (128 LUTs)
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00001010", "00001010", "00001010", "00001010",
      "10100000", "10100000", "10100000", "10100000",
      "10100000", "10100000", "10100000", "10100000",
      "10100000", "10100000", "10100000", "10100000",
      "10100000", "10100000", "10100000", "10100000",
      "10100000", "10100000", "10100000", "10100000",
      "10100000", "10100000", "10100000", "10100000",
      "01010000", "01010000", "10100000", "10100000",
      -- Combiner LUT values (16 LUTs)
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00001110",
      -- Count LUT values (16 LUTs)
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000000",
      "00000000", "00000000", "00000000", "00000001",
      -- Flag LUT values (2 LUTs)
      "00000000", "00000000", "00000000", "00000001",
      "00000000", "00000000", "00000000", "00000000"
   );
-- Or (T0[0111111111111111, Normal  ] T1[0111111111111110, Normal  ] ), Count = 1
   
   variable receiveData   : DataBusType;
   constant preTrigCount  : positive := 10000;
   constant sampleCount   : positive := 40000;
   variable stimulusIndex : natural := 0;

   begin
      status <= "Start ";
   
      wait for 60 ns;

      status <= "Lu-Pat";

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_PATTERN_STIMULUS/4, 8)));

      for index in 1 to SIM_NUM_PATTERN_STIMULUS/4 loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_PATTERN_STIMULUS/4, 8)));
      
      for index in 1 to SIM_NUM_PATTERN_STIMULUS/4 loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_PATTERN_STIMULUS/4, 8)));
      
      for index in 1 to SIM_NUM_PATTERN_STIMULUS/4 loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_PATTERN_STIMULUS/4, 8)));
      
      for index in 1 to SIM_NUM_PATTERN_STIMULUS/4 loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      status <= "Lu-Com";

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_COMBINER_STIMULUS, 8)));
      
      for index in 1 to SIM_NUM_COMBINER_STIMULUS loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      status <= "Lu-Cnt";

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_COUNT_STIMULUS, 8)));
      
      for index in 1 to SIM_NUM_COUNT_STIMULUS loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;

      status <= "Lu-Flg";

      sendToAnalyser(C_LUT_CONFIG);
      sendToAnalyser(std_logic_vector(to_unsigned(SIM_NUM_FLAG_STIMULUS, 8)));
      
      for index in 1 to SIM_NUM_FLAG_STIMULUS loop
         sendToAnalyser(stimulus(stimulusIndex));
         stimulusIndex := stimulusIndex + 1;
      end loop;
      
      assert (stimulusIndex = stimulus'length) report "Transmitting stimulus array not complete";
      
      status <= "Init  ";
      if (initializing = '1') then
         wait until (initializing = '0');
      end if;
      
      status <= "W-Ptrg";
      sendToAnalyser(C_WR_PRETRIG);
      sendToAnalyser("00000011");
      sendToAnalyser(std_logic_vector(to_unsigned(preTrigCount mod 256, 8)));
      sendToAnalyser(std_logic_vector(to_unsigned((preTrigCount/256) mod 256, 8)));
      sendToAnalyser(std_logic_vector(to_unsigned(preTrigCount/65526, 8)));

      status <= "W-Size";
      sendToAnalyser(C_WR_CAPTURE);
      sendToAnalyser("00000011");
      sendToAnalyser(std_logic_vector(to_unsigned(sampleCount mod 256, 8)));
      sendToAnalyser(std_logic_vector(to_unsigned((sampleCount/256) mod 256, 8)));
      sendToAnalyser(std_logic_vector(to_unsigned(sampleCount/65526, 8)));

      status <= "Idle  ";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser("00000000");

      status <= "Spd50n";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser(C_CONTROL_S_100ns);

      status <= "Enable";
      sendToAnalyser(C_WR_CONTROL);
      sendToAnalyser("00000001");
      sendToAnalyser(C_CONTROL_S_100ns or C_CONTROL_START_ACQ);

      status <= "Poll  ";
      loop
         sendToAnalyser(C_RD_STATUS);
         sendToAnalyser("00000001");
         receiveFromAnalyser(receiveData);
         case receiveData(2 downto 0) is
            when "000"  => status <= "Idle  ";
            when "001"  => status <= "PreTrg";
            when "010"  => status <= "Armed ";
            when "011"  => status <= "Run   ";
            when "100"  => status <= "Done  ";
            when others => status <= "??????";
         end case;
         exit when (receiveData(2 downto 0) = "100");
      end loop;
      wait for 200 ns;
      
      status <= "Rd200a";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(200, 8)));
      for index in 1 to 200 loop
         receiveFromAnalyser(receiveData);
      end loop;
      
      status <= "Rd200b";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(200, 8)));
      for index in 1 to 200 loop
         receiveFromAnalyser(receiveData);
      end loop;
      
      status <= "Rd200c";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(200, 8)));
      for index in 1 to 200 loop
         receiveFromAnalyser(receiveData);
      end loop;
      
      status <= "Rd200d";
      sendToAnalyser(C_RD_BUFFER);
      sendToAnalyser(std_logic_vector(to_unsigned(200, 8)));      
      for index in 1 to 200 loop
         receiveFromAnalyser(receiveData);
      end loop;

      status <= "Done  ";
--      writeLutsComplete <= true;

      wait for 100 ns;
      complete <= true;

      wait for 40 ns;
      wait;
   end process;

   WaveformProc:
   Process
   type StimulusArray is array (0 to 60) of SampleDataType;
   variable stimulus : StimulusArray := (
   --  111111
   --  5432109876543210
      "0000111111111111", 
      "0001111111111111", 
      "0010111111111111", 
      "0011111111111111", 
      "0100111111111111", 
      "0101111111111111", 
      "0110111111111111", 
      "0111111111111111", 
      "1000111111111111", 
      "1001111111111111", 
      "1010111111111111", 
      "1011111111111111", 
      "1100011111111111", 
      "1101111111111110", 
      "1110111111111110", 
      "1111111111111111", 
      "0000111111111111", 
      "0001111111111110", 
      "0010111111111110", 
      "0011111111111110", 
      "0100111111111110", 
      "0101111111111110", 
      "0110111111111110", 
      "0111111111111110", 
      "1000111111111110", 
      "1001111111111111", 
      "1010111111111111", 
      "1011111111111111", 
      "1100111111111111", 
      "1101111111111111", 
      "1110111111111111", 
      "1111111111111111", 
      "0000111111111111", 
      "0001111111111111", 
      "0010111111111110", 
      "0011111111111110", 
      "0100111111111111", 
      "0101111111111111", 
      "0110111111111111", 
      "0111111111111110", 
      "1000111111111111", 
      "1001111111111110", 
      "1010111111111111", 
      "1011111111111110", 
      "1100111111111111", 
      "1101111111111110", 
      "1110111111111111", 
      "1111111111111110", 
      "0000111111111111", 
      "0001111111111110", 
      "0010111111111111", 
      "0011111111111110", 
      "0100111111111111", 
      "0101111111111110", 
      "0110111111111111", 
      "0111111111111110", 
      "1000111111111111", 
      "1001111111111110", 
      "1010111111111111", 
      "1011111111111110", 
      "1100111111111111", 
      others => x"1234"
   );
   
   variable sampleCounter : SampleDataType := (others => '0');

   begin
      wait until armed = '1';
      wait until falling_edge(clock_100MHz);

      for index in stimulus'range loop
         wait until (doSample = '1') and falling_edge(clock_100MHz);
         sample <= stimulus(index);
      end loop;
      
      while (sampling = '1') loop
         wait until (doSample = '1') and falling_edge(clock_100MHz);
         sample <= sampleCounter;
         sampleCounter := std_logic_vector(unsigned(sampleCounter) + 1);
      end loop;

      -- if (sampling = '1') then
         -- wait until sampling = '0';
      -- end if;
      
      -- wait for 100 ns;
      -- complete <= true;

      -- wait for 40 ns;
      
      wait;
   end process;
   
END;
