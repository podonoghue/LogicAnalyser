LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

ENTITY TriggerBusInterface_tb IS
END TriggerBusInterface_tb;
 
ARCHITECTURE behavior OF TriggerBusInterface_tb IS 
 
   --Inputs
   signal reset   : std_logic    := '0';
   signal clock   : std_logic    := '0';
   signal dataIn  : DataBusType  := (others => '0');
   signal dataOut : DataBusType  := (others => '0');
   signal wr      : std_logic    := '0';
   signal rd      : std_logic    := '0';
   signal busy    : std_logic;

   -- LUT control
   signal lut_config_ce  : std_logic := '0';
   signal lut_config_in  : std_logic := '0';
   signal lut_config_out : std_logic := '0';

   -- Clock period definitions
   constant clock_period : time := 10 ns;
   signal   complete     : boolean  := false;

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   TriggerBusInterface_uut:
   entity work.TriggerBusInterface 
   PORT MAP (
      reset   => reset,
      clock   => clock,

      wr      => wr,
      dataIn  => dataIn,

      rd      => rd,
      dataOut => dataOut,
      
      busy    => busy,

      lut_config_ce  => lut_config_ce,
      lut_config_in  => lut_config_in,
      lut_config_out => lut_config_out
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
   
   -- Stimulus process
   stim_proc: process
   
   procedure writeLut(addrIn : AddressBusType; data : DataBusType) is
   begin
      wr     <= '1';
      dataIn <= data;
      wait until falling_edge(clock);
      wr     <= '0';
      wait for 40.5*clock_period;
   end procedure;
   
   type StiumulusEntry is record
      addr : AddressBusType;
      data : DataBusType;
   end record;
   
   type StimulusArray is array (0 to 5) of StiumulusEntry;
   variable stimulus : StimulusArray := (
      ( to_unsigned(CONTROL_ADDRESS, ADDRESS_BUS_WIDTH), x"A5" ),
      ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), x"5A" ),
      others => ( to_unsigned(LUT_SR_ADDRESS, ADDRESS_BUS_WIDTH), x"5A" )
   );

   begin	
      reset <= '1';
      wait for clock_period*10;
      reset <= '0';

      for index in 0 to stimulus'length-1 loop
         writeLut(stimulus(index).addr, stimulus(index).data);
      end loop;
      
      complete <= true;
      wait for 10 ns;
      wait;
      
   end process;

END;
