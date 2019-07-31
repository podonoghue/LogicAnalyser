library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity Prescaler is
   port( 
      clock_100MHz      : in   std_logic; 
      enable            : in   std_logic;
      selectDivider     : in   std_logic_vector(1 downto 0);
      selectDecade      : in   std_logic_vector(1 downto 0);
      doSample          : out  std_logic
   );
end Prescaler;

architecture Behavioral of Prescaler is

-- Number of modules chained together
constant NUM_CHAINED_MODULES   : integer := 3;
signal   loopback_chain        : std_logic_vector(NUM_CHAINED_MODULES-1 downto 0);
signal   ce_chainIn            : std_logic_vector(NUM_CHAINED_MODULES   downto 0);
signal   div_chain             : std_logic_vector(NUM_CHAINED_MODULES   downto 0);

signal   prescaled_ce          : std_logic;

signal   div1_control          : std_logic_vector(3 downto 0);

signal   loopback_2            : std_logic;
signal   loopback_5            : std_logic;
signal   loopback_10           : std_logic;

signal   prescaler             : std_logic;

begin
   
   SRL16E_2_inst : SRL16E
   generic map (
      init => x"0001"
   )
   port map (
      clk =>  clock_100MHz, -- clock_100MHz input
      a0  =>  '1',   -- Make 2-bit SRL
      a1  =>  '0',
      a2  =>  '0',
      a3  =>  '0',
      ce  =>  '1',                        -- Clock enable input
      q   =>  loopback_2, -- SRL data output
      d   =>  loopback_2  -- SRL data input
   );   
   
   SRL16E_5_inst : SRL16E
   generic map (
      init => x"0001"
   )
   port map (
      clk =>  clock_100MHz, -- clock_100MHz input
      a0  =>  '0',   -- Make 5-bit SRL
      a1  =>  '0',
      a2  =>  '1',
      a3  =>  '0',
      ce  =>  '1',                        -- Clock enable input
      q   =>  loopback_5, -- SRL data output
      d   =>  loopback_5  -- SRL data input
   );   
   
   SRL16E_10_inst : SRL16E
   generic map (
      init => x"0001"
   )
   port map (
      clk =>  clock_100MHz, -- clock_100MHz input
      a0  =>  '1',   -- Make 10-bit SRL
      a1  =>  '0',
      a2  =>  '0',
      a3  =>  '1',
      ce  =>  '1',                        -- Clock enable input
      q   =>  loopback_10, -- SRL data output
      d   =>  loopback_10  -- SRL data input
   );   
   
   prescaler_proc:
   process(selectDivider, loopback_2, loopback_5, loopback_10, clock_100MHz)
      variable   pres   : std_logic;
   begin
      case (selectDivider) is
         when "00"   => pres := '1';
         when "01"   => pres := loopback_2;
         when "10"   => pres := loopback_5;
         when "11"   => pres := loopback_10;
         when others => pres := '0';
      end case;
      
      if rising_edge(clock_100MHz) then
         prescaler <= pres;
      end if;
   end process;
   
   GenerateDecades: -- Each trigger step
   for counterBit in NUM_CHAINED_MODULES-1 downto 0 generate
   
   begin
      SRL16E_inst : SRL16E
      generic map (
         init => x"0001"
      )
      port map (
         clk =>  clock_100MHz, -- clock_100MHz input
         a0  =>  '1',   -- Make 10-bit SRL
         a1  =>  '0',
         a2  =>  '0',
         a3  =>  '1',
         ce  =>  ce_chainIn(counterBit),     -- Clock enable input
         q   =>  loopback_chain(counterBit), -- SRL data output
         d   =>  loopback_chain(counterBit)  -- SRL data input
      );   
   end generate;
  
   ce_chainIn(0) <= prescaler;
   
   MutipleLutChainGenerate:
   if (NUM_CHAINED_MODULES > 1) generate
   begin
      GenerateDecades: -- Each decade
      for counterBit in NUM_CHAINED_MODULES downto 1 generate
      begin
         ce_chainIn(counterBit) <= and_reduce(loopback_chain(counterBit-1 downto 0) & prescaler);
      end generate;
   end generate;

   div_chain      <= ce_chainIn;
   prescaled_ce   <= div_chain(to_integer(unsigned(selectDecade))) when rising_edge(clock_100MHz);
   doSample       <= (prescaled_ce and enable) when rising_edge(clock_100MHz);
   
end Behavioral;

