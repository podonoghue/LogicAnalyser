library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.all;
use work.LogicAnalyserPackage.all;

entity ft2232h_Interface is
   port ( 
      reset           : in   std_logic;
      clock_100MHz    : in   std_logic;

      -- Bus interface
      ft2232h_rxf_n   : in    std_logic;   -- Rx FIFO Full
      ft2232h_txe_n   : in    std_logic;   -- Tx FIFO Empty 
      ft2232h_rd_n    : out   std_logic;   -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_wr      : out   std_logic;   -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data    : inOut DataBusType; -- FIFO Data I/O
      
      receive_data    : out   DataBusType;
      receive_data_st : out   std_logic;

      write_data      : in    DataBusType;
      write_data_req  : in    std_logic
   );
end ft2232h_Interface;

architecture Behavioral of ft2232h_Interface is

   type StateType is (s_idle, s_receive, s_receive_release, s_send, s_send_release );
   signal state : StateType;
   
   signal   delayCount     : natural range 0 to 5;
   constant rd_low_delay   : natural := 5;
   constant rd_high_delay  : natural := 5;

   constant wr_high_delay  : natural := 5;
   constant wr_low_delay   : natural := 2;
   
begin
   
   process(clock_100MHz, reset)
   begin
      if rising_edge(clock_100MHz) then
         ft2232h_rd_n      <= '1';
         ft2232h_wr        <= '0';
         receive_data_st   <= '0';
         ft2232h_data      <= (others => 'Z');

         case (state) is
            when s_idle =>
               if (ft2232h_rxf_n = '0') then
                  state      <= s_receive;
                  delayCount <= 0;
               elsif (ft2232h_txe_n = '0') and (write_data_req = '1') then
                  state     <=  s_send;
                  ft2232h_wr        <= '1';
                  delayCount <= 0;
               end if;

            when s_receive =>
               ft2232h_rd_n       <= '0';
               if (delayCount = rd_low_delay) then
                  state             <= s_receive_release;
                  receive_data      <= ft2232h_data;
                  receive_data_st   <= '1';
                  delayCount        <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;
               
            when s_receive_release =>
               if (delayCount = rd_high_delay) then
                  state      <= s_idle;
                  delayCount <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;

            when s_send =>
               ft2232h_wr         <= '1';
               ft2232h_data       <= write_data;
               if (delayCount = wr_high_delay) then
                  state      <= s_send_release;
                  delayCount <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;

            when s_send_release =>
               ft2232h_wr         <= '0';
               if (delayCount = wr_low_delay) then
                  state      <= s_idle;
                  delayCount <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;
         end case;
         if (reset = '1') then
            state <= s_idle;
         end if;
      end if;
   end process;

end Behavioral;

