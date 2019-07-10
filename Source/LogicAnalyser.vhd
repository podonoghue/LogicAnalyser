library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
--use ieee.std_logic_misc.all;

use work.all;
use work.LogicAnalyserPackage.all;
 
entity LogicAnalyser is
   port ( 
      reset          : in  std_logic;
      clock          : in  std_logic;
      
      -- Trigger logic
      enable         : in  std_logic;
      sample         : in  SampleDataType; -- Sample data
      trigger        : out std_logic;      -- Trigger output

      -- LUT serial configuration          
      lut_clock      : in  std_logic;  -- Used for LUT shift register          
      lut_config_ce  : in  std_logic;  -- Clock enable for LUT shift register
      lut_config_in  : in  std_logic;  -- Serial in for LUT shift register MSB first in
      lut_config_out : out std_logic   -- Serial out for LUT shift register
  );
end LogicAnalyser;
 
architecture Behavior of LogicAnalyser is 
 
   -- --Inputs
   -- signal reset : std_logic := '0';
   -- signal clock : std_logic := '0';
   -- signal enable : std_logic := '0';
   -- signal sample : std_logic_vector(15 downto 0) := (others => '0');
   -- signal lut_clock : std_logic := '0';
   -- signal lut_config_ce : std_logic := '0';
   -- signal lut_config_in : std_logic := '0';

 	-- --Outputs
   -- signal trigger : std_logic;
   -- signal lut_config_out : std_logic;

signal currentSample : SampleDataType;
signal lastSample    : SampleDataType;

begin
 
   Sampling_proc:
   process(reset, clock) 
   begin
      if (reset = '1') then
         currentSample <= (others => '0');
         lastSample    <= (others => '0');
      elsif rising_edge(clock) then
         currentSample <= sample;
         lastSample    <= currentSample;
      end if;
   end process;

	-- Instantiate the Unit Under Test (UUT)
   TriggerBlock_inst: 
   entity TriggerBlock port map (
       reset            => reset,
       clock            => clock,
       enable           => enable,
       currentSample    => currentSample,
       lastSample       => lastSample,
       trigger          => trigger,
       lut_clock        => lut_clock,
       lut_config_ce    => lut_config_ce,
       lut_config_in    => lut_config_in,
       lut_config_out   => lut_config_out
     );

end;
