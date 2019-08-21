library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.logicanalyserpackage.all;

entity sdram is
   port (
      sdram_clk     : in     std_logic;
      sdram_cke     : in     std_logic;
      sdram_cs_n    : in     std_logic;
      sdram_ras_n   : in     std_logic;
      sdram_cas_n   : in     std_logic;
      sdram_we_n    : in     std_logic;
      sdram_dqm     : in     std_logic_vector ( 1 downto 0);
      sdram_addr    : in     std_logic_vector (12 downto 0);
      sdram_ba      : in     std_logic_vector ( 1 downto 0);
      sdram_data    : inout  std_logic_vector (15 downto 0) := (others => 'Z')
   );
end sdram;

architecture behavioral of sdram is
begin

   sdram_model_inst:
   entity work.mt48lc16m16a2 
   port map (
      BA0      => sdram_ba(0),    
      BA1      => sdram_ba(1),    
      DQMH     => sdram_dqm(1),   
      DQML     => sdram_dqm(0),   
      DQ0      => sdram_data(0),    
      DQ1      => sdram_data(1),    
      DQ2      => sdram_data(2),    
      DQ3      => sdram_data(3),    
      DQ4      => sdram_data(4),    
      DQ5      => sdram_data(5),    
      DQ6      => sdram_data(6),    
      DQ7      => sdram_data(7),    
      DQ8      => sdram_data(8),    
      DQ9      => sdram_data(9),    
      DQ10     => sdram_data(10),   
      DQ11     => sdram_data(11),   
      DQ12     => sdram_data(12),   
      DQ13     => sdram_data(13),   
      DQ14     => sdram_data(14),   
      DQ15     => sdram_data(15),   
      CLK      => sdram_clk,    
      CKE      => sdram_cke,    
      A0       => sdram_addr(0),     
      A1       => sdram_addr(1),     
      A2       => sdram_addr(2),     
      A3       => sdram_addr(3),     
      A4       => sdram_addr(4),     
      A5       => sdram_addr(5),     
      A6       => sdram_addr(6),     
      A7       => sdram_addr(7),     
      A8       => sdram_addr(8),     
      A9       => sdram_addr(9),     
      A10      => sdram_addr(10),    
      A11      => sdram_addr(11),    
      A12      => sdram_addr(12),    
      WENeg    => sdram_we_n,  
      RASNeg   => sdram_ras_n, 
      CSNeg    => sdram_cs_n,  
      CASNeg   => sdram_cas_n 
   );
   
end Behavioral;