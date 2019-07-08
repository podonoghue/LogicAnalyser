library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.all;
use work.LogicAnalyserPackage.all;
 
entity triggerbasictest is
end triggerbasictest;
 
architecture behavior of triggerbasictest is 

   constant XX : std_logic_vector(31 downto 0) := "00000000000000001111111111111111";
   constant XH : std_logic_vector(31 downto 0) := "00000000000000001010101010101010";
   constant XL : std_logic_vector(31 downto 0) := "00000000000000000101010101010101";
   constant XR : std_logic_vector(31 downto 0) := "00000000000000000010001000100010";
   constant XF : std_logic_vector(31 downto 0) := "00000000000000000100010001000100";
   constant XC : std_logic_vector(31 downto 0) := "00000000000000000110011001100110";
   constant HX : std_logic_vector(31 downto 0) := "00000000000000001111000011110000";
   constant HH : std_logic_vector(31 downto 0) := "00000000000000001010000010100000";
   constant HL : std_logic_vector(31 downto 0) := "00000000000000000101000001010000";
   constant HR : std_logic_vector(31 downto 0) := "00000000000000000010000000100000";
   constant HF : std_logic_vector(31 downto 0) := "00000000000000000100000001000000";
   constant HC : std_logic_vector(31 downto 0) := "00000000000000000110000001100000";
   constant LX : std_logic_vector(31 downto 0) := "00000000000000000000111100001111";
   constant LH : std_logic_vector(31 downto 0) := "00000000000000000000101000001010";
   constant LL : std_logic_vector(31 downto 0) := "00000000000000000000010100000101";
   constant LR : std_logic_vector(31 downto 0) := "00000000000000000000001000000010";
   constant LF : std_logic_vector(31 downto 0) := "00000000000000000000010000000100";
   constant LC : std_logic_vector(31 downto 0) := "00000000000000000000011000000110";
   constant RX : std_logic_vector(31 downto 0) := "00000000000000000000000011110000";
   constant RH : std_logic_vector(31 downto 0) := "00000000000000000000000010100000";
   constant RL : std_logic_vector(31 downto 0) := "00000000000000000000000001010000";
   constant RR : std_logic_vector(31 downto 0) := "00000000000000000000000000100000";
   constant RF : std_logic_vector(31 downto 0) := "00000000000000000000000001000000";
   constant RC : std_logic_vector(31 downto 0) := "00000000000000000000000001100000";
   constant FX : std_logic_vector(31 downto 0) := "00000000000000000000111100000000";
   constant FH : std_logic_vector(31 downto 0) := "00000000000000000000101000000000";
   constant FL : std_logic_vector(31 downto 0) := "00000000000000000000010100000000";
   constant FR : std_logic_vector(31 downto 0) := "00000000000000000000001000000000";
   constant FF : std_logic_vector(31 downto 0) := "00000000000000000000010000000000";
   constant FC : std_logic_vector(31 downto 0) := "00000000000000000000011000000000";
   constant CX : std_logic_vector(31 downto 0) := "00000000000000000000111111110000";
   constant CH : std_logic_vector(31 downto 0) := "00000000000000000000101010100000";
   constant CL : std_logic_vector(31 downto 0) := "00000000000000000000010101010000";
   constant CR : std_logic_vector(31 downto 0) := "00000000000000000000001000100000";
   constant CF : std_logic_vector(31 downto 0) := "00000000000000000000010001000000";
   constant CC : std_logic_vector(31 downto 0) := "00000000000000000000011001100000";
  
   signal complete      : boolean := false;

   --inputs
   signal clock         : std_logic := '0';
   signal sample        : SampleDataType := (others => '0');
   signal lastsample    : SampleDataType := (others => '0');
   signal mode          : std_logic := '0';
   signal lut_config_ce : std_logic := '0';
   signal lut_config_in : std_logic := '0';

 	--outputs
   signal trigger          : std_logic;
   signal lut_config_out   : std_logic;

   -- clock period definitions
   constant clock_period : time := 10 ns;
 
   signal id : string(1 to 5) := "     ";
   
begin
 
	-- instantiate the unit under test (uut)
   uut: entity work.triggerbasic port map (
          clock            => clock,
          sample           => sample,
          lastsample       => lastsample,
          mode             => mode,
          trigger          => trigger,
          lut_config_ce    => lut_config_ce,
          lut_config_in    => lut_config_in,
          lut_config_out   => lut_config_out
        );

   -- clock process definitions
   clock_process :
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

   lastsample <= sample when rising_edge(clock);

   -- Stimulus process
   stim_proc: 
   process
   
   -- Type for trigger entry
   type StimulusType is 
   record
      data    : SampleDataType; 
      repeat  : natural;
   end record;

   type StimulusArray is array (0 to 20) of StimulusType;
   variable stimulus : StimulusArray := (
      ("0000", 2),
      ("1100", 3),
      ("0000", 5),
      ("1001", 3),
      ("0000", 5),
      ("1001", 5),
      ("0000", 6),
      ("1101", 3),
      ("0000", 5),
      ("1011", 3),
      others => ("0000", 0)
   );
   
   type TestType is 
   record
      name        : string(1 to 5);
      pattern1    : std_logic_vector(31 downto 0); 
      pattern0    : std_logic_vector(31 downto 0); 
   end record;
   type TestArray is array (0 to 5) of TestType;
   variable tests : TestArray := (
      ( "XX-XX", XX, XX ), 
      ( "HX-XX", HX, XX ),
      ( "LX-XX", LX, XX ),
      ( "RX-XX", RX, XX ),
      ( "FX-XX", FX, XX ),
      ( "CX-XX", CX, XX )  
   );
   
   procedure writeLut(data: std_logic_vector(31 downto 0)) is
   begin
      wait for clock_period/8;
      lut_config_ce <= '1';
      for ticks in data'left downto data'right loop
         lut_config_in <= data(ticks);
         wait until rising_edge(clock);
         wait for clock_period/4;
      end loop;
      lut_config_ce <= '0';
   end procedure;
   
   procedure writeDataPattern(value : StimulusType) is
   begin
      wait for clock_period/8;
      for ticks in value.repeat downto 1 loop
         sample <= value.data;
         wait until rising_edge(clock);
         wait for clock_period/4;
      end loop;
   end procedure;
   
   begin
      wait until falling_edge(clock);
      wait until falling_edge(clock);
      writeLut(x"00000000");
      wait for 20 ns;
      
      for index in tests'left to tests'right loop
         -- Configure Comparitor 
         writeLut(tests(index).pattern1);
         writeLut(tests(index).pattern0);
         
         -- Apply test sequence
         id <= tests(index).name;
         
         for sIndex in tests'left to tests'right loop
            writeDataPattern(stimulus(sIndex));
         end loop;
      end loop;

      complete <= true;
      wait for 20 ns;
      
      -- Kill stimulus
      wait;
   end process;

end;
