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
   type decode is (unsel_c, lmr_c, ref_c, pre_c, act_c, wr_c, rd_c, term_c, nop_c);
   signal command : decode := unsel_c;

   signal dqm_sr        : std_logic_vector( 3 downto 0) := (others => '0');
   signal selected_bank : std_logic_vector( 1 downto 0) := (others => '0');
   signal column        : std_logic_vector( 8 downto 0) := (others => '0');

   -- Only eight rows of four banks are modeled
   type   memory_array is array (0 to 8 * 512 * 4 -1 ) of std_logic_vector(15 downto 0);
   type   row_array    is array (0 to 3)               of std_logic_vector( 2 downto 0);

   signal memory        : memory_array  := (others => (x"A55A"));
   signal active_row    : row_array     := (others => (others => '0'));
   signal is_row_active : std_logic_vector( 3 downto 0) := (others => '0');
   signal mode_reg      : std_logic_vector(12 downto 0) := (others => '0');
   
   alias burst_mode     : std_logic        is mode_reg(9);
   alias burst_length   : std_logic_vector is mode_reg(2 downto 0);
   alias cas_latency    : std_logic_vector is mode_reg(6 downto 4);

   signal data_delay1   : std_logic_vector(15 downto 0) := (others => '0');
   signal data_delay2   : std_logic_vector(15 downto 0) := (others => '0');
   signal data_delay3   : std_logic_vector(15 downto 0) := (others => '0');
   signal addr_index    : std_logic_vector(13 downto 0) := (others => '0');

   signal wr_mask       : std_logic_vector( 1 downto 0) := (others => '0');
   signal wr_data       : std_logic_vector(15 downto 0) := (others => '0');
   signal wr_burst      : std_logic_vector( 8 downto 0) := (others => '0');
   signal rd_burst      : std_logic_vector( 9 downto 0) := (others => '0');

   signal sdram_data_out : std_logic_vector(15 downto 0) := (others => '0');
   signal sdram_hiz      : std_logic;
   
begin

   addr_index <= active_row(to_integer(unsigned(selected_bank))) & selected_bank & column;

   decode_proc:
   process(sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n)
      variable cmd : std_logic_vector(2 downto 0);
      begin
         if sdram_cs_n = '1' then
            command <= unsel_c;
         else
            cmd := sdram_ras_n & sdram_cas_n & sdram_we_n;
            case cmd is
               when "000"  => command <= LMR_c;
               when "001"  => command <= REF_c;
               when "010"  => command <= PRE_c;
               when "011"  => command <= ACT_c;
               when "100"  => command <= WR_c;
               when "101"  => command <= RD_c;
               when "110"  => command <= TERM_c;
               when others => command <= NOP_c;
            end case;
         end if;
      end process;

   data_process :
   process(sdram_clk)
      begin
         if rising_edge(sdram_clk) then

            -- This implements the data masks, gets updated when a read command is sent
            rd_burst(8 downto 0) <= rd_burst(9 downto 1);
            column               <= std_logic_vector(unsigned(column)+1);
            wr_burst(7 downto 0) <= wr_burst(8 downto 1);

            -- Process any pending writes
            if wr_burst(0) = '1' and wr_mask(0) = '1' then
               memory(to_integer(unsigned(addr_index)))(7 downto 0) <= wr_data(7 downto 0);
            end if;
            if wr_burst(0) = '1' and wr_mask(1) = '1' then
               memory(to_integer(unsigned(addr_index)))(15 downto 8) <= wr_data(15 downto 8);
            end if;

            wr_data <= sdram_data;

            -- default is not to write
            wr_mask <= "00";
            if command = wr_c then
               rd_burst <= (others => '0');
               column        <= sdram_addr(8 downto 0);
               selected_bank <= sdram_ba;
               if burst_mode = '1' then
                  wr_burst <= "000000001";
               else
                  case burst_length is
                     when "000" => wr_burst <= "000000001";
                     when "001" => wr_burst <= "000000011";
                     when "010" => wr_burst <= "000001111";
                     when "011" => wr_burst <= "011111111";
                     when "111" => wr_burst <= "111111111";  -- full page
                     when others =>
                  end case;
               end if;
            elsif command = lmr_c then
               mode_reg <= sdram_addr;
            elsif command = act_c then
               -- Open a row in a bank
               active_row(to_integer(unsigned(sdram_ba)))    <= sdram_addr(2 downto 0);
               is_row_active(to_integer(unsigned(sdram_ba))) <= '1';
            elsif command = pre_c then
               -- Close off the row
               active_row(to_integer(unsigned(sdram_ba)))    <= (others => 'X');
               is_row_active(to_integer(unsigned(sdram_ba))) <= '0';
            elsif command = RD_c then
               wr_burst      <= (others => '0');
               column        <= sdram_addr(8 downto 0);
               selected_bank <= sdram_ba;
               -- This sets the burst length
               case burst_length is
                  when "000" => rd_burst <= "0000000001";
                  when "001" => rd_burst <= "0000000011";
                  when "010" => rd_burst <= "0000001111";
                  when "011" => rd_burst <= "0011111111";
                  when "111" => rd_burst <= "0111111111";  -- full page
                  when others =>
                     -- full page not implemented
               end case;
            end if;

            -- This is the logic that implements the CAS delay. Here is enough for CAS=2
            if (cas_latency = "010") then
               dqm_sr  <= "11"&sdram_dqm;
               data_delay1 <= memory(to_integer(unsigned(addr_index)));
            elsif (cas_latency = "011") then
               dqm_sr  <= sdram_dqm & dqm_sr(3 downto 2);
               data_delay1 <= data_delay2;
               data_delay2 <= memory(to_integer(unsigned(addr_index)));
            else
               data_delay1 <= data_delay2;
               data_delay2 <= data_delay3;
               data_delay3 <= memory(to_integer(unsigned(addr_index)));
            end if;

            -- Output masks lag a cycle
            wr_mask <= not sdram_dqm;

         end if;
      end process;

   sdram_data <= sdram_data_out when (sdram_hiz = '0') else (others => 'Z');
   
   data2_process :
   process(sdram_clk)
      constant tAC  : time := 6 ns;
      constant tOH  : time := 3 ns;
      constant tHZ  : time := 6 ns;
      constant tLZ  : time := 1 ns;
      begin
         if rising_edge(sdram_clk) then
            if rd_burst(0) = '1' and dqm_sr(0) = '0' then
               sdram_data_out( 7 downto 0) <= data_delay1(7 downto 0) after tAC;
               sdram_hiz <= '0' after tLZ;
            else
               sdram_data_out( 7 downto 0) <= (others => 'X') after tOH;
               sdram_hiz <= '1' after tHZ;
            end if;

            if rd_burst(0) = '1' and dqm_sr(1) = '0' then
               sdram_data_out(15 downto 8) <= data_delay1(15 downto 8) after tAC;
               sdram_hiz <= '0' after tLZ;
            else
               sdram_data_out(15 downto 8) <= (others => 'X') after tOH;
               sdram_hiz <= '1' after tHZ;
            end if;
         elsif falling_edge(sdram_clk) then
         end if;
      end process;

end Behavioral;