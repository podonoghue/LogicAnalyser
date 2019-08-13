library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.all;
use work.LogicAnalyserPackage.all;

entity ft2232h_Interface is
   port ( 
      clock_100MHz                : in   std_logic;

      -- FT2232 interface
      ft2232h_rxf_n               : in    std_logic;     -- Rx FIFO Full
      ft2232h_rd_n                : out   std_logic;     -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_txe_n               : in    std_logic;     -- Tx FIFO Empty 
      ft2232h_wr_n                : out   std_logic;     -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data                : inOut DataBusType;   -- FIFO Data I/O
      ft2232h_siwu_n              : out   std_logic;     -- Flush USB buffer(Send Immediate / WakeUp signal)

      -- Receive interface      
      host_receive_data_request   : in    std_logic;     -- Request data from host
      host_receive_data_available : out   std_logic;     -- Requested data from host is available
      host_receive_data           : out   DataBusType;   -- Receive data

      -- Send interface
      host_transmit_data_ready    : out   std_logic;     -- Indicates interface is ready to send data to host
      host_transmit_data          : in    DataBusType;   -- Transmit data
      host_transmit_data_request  : in    std_logic      -- Send data to host request
   );
end ft2232h_Interface;

architecture Behavioral of ft2232h_Interface is

   type StateType is (s_idle, s_receive, s_receive_release, s_send, s_send_release );
   signal state : StateType := s_idle;
   
   signal   delayCount     : natural range 0 to 5;
   constant rd_low_delay   : natural := 5;
   constant rd_high_delay  : natural := 5;

   constant wr_high_delay  : natural := 5;
   constant wr_low_delay   : natural := 2;

   signal ft2232h_rxf      : std_logic;   -- Rx FIFO Full
   signal ft2232h_txe      : std_logic;   -- Tx FIFO Empty 
   signal ft2232h_rd       : std_logic;   -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
   signal ft2232h_wr       : std_logic;   -- Tx FIFO Write (Data captured on rising edge)

   signal ft2232h_data_oe  : std_logic                   := '0';
   signal ft2232h_data_ff  : DataBusType                 := (others => '0');
   signal host_transmit_data_ready_internal : std_logic  := '0';
   
begin
   ft2232h_siwu_n <= '1';

   ft2232h_rxf  <= not ft2232h_rxf_n;
   ft2232h_rd_n <= not ft2232h_rd;

   ft2232h_txe  <= not ft2232h_txe_n;
   ft2232h_wr_n <= not ft2232h_wr;
   
   ft2232h_data <= ft2232h_data_ff when (ft2232h_data_oe = '1') else (others => 'Z');
   
   host_transmit_data_ready <= host_transmit_data_ready_internal;
      
   process(clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         ft2232h_rd                          <= '0';
         ft2232h_wr                          <= '0';
         host_receive_data_available         <= '0';
         ft2232h_data_oe                     <= '0';
         host_transmit_data_ready_internal   <= '0';

         case (state) is
            when s_idle =>
               -- Note - Because host_transmit_data_ready is delayed by 1 clock on entry
               --        to s_idle there is a small window that allows host_receive_data_request
               --        to be accepted.  This ensures that the interface is always receptive to commands
               --        from host.
               --        At the same time, host_transmit_data_request is always acted on immediatedly if
               --        host_transmit_data_ready is active.
               
               if (host_transmit_data_ready_internal = '1') and (host_transmit_data_request = '1') then
                  ft2232h_data_ff <= host_transmit_data;
                  state           <=  s_send;
                  ft2232h_wr      <= '1';
                  delayCount      <= 0;
               elsif (ft2232h_rxf = '1') and (host_receive_data_request = '1') then
                  state       <= s_receive;
                  ft2232h_rd  <= '1';
                  delayCount  <= 0;
               else
                  -- Can only send when FT2232 can accept data and interface is idle
                  host_transmit_data_ready_internal <= ft2232h_txe;               
               end if;

            when s_receive =>
               ft2232h_rd  <= '1';
               if (delayCount = rd_low_delay) then
                  state                         <= s_receive_release;
                  host_receive_data             <= ft2232h_data;
                  host_receive_data_available   <= '1';
                  delayCount                    <= 0;
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
               ft2232h_wr        <= '1';
               ft2232h_data_oe   <= '1';
               if (delayCount = wr_high_delay) then
                  state      <= s_send_release;
                  delayCount <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;

            when s_send_release =>
               ft2232h_wr <= '0';
               if (delayCount = wr_low_delay) then
                  state      <= s_idle;
                  delayCount <= 0;
               else
                  delayCount <= delayCount + 1;
               end if;
         end case;
      end if;
   end process;

end Behavioral;

