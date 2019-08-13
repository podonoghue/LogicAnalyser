library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyser is
   port (
      clock_100MHz   : in    std_logic;
      clock_110MHz   : in    std_logic;
      clock_110MHz_n : in    std_logic;

      -- FT2232 Interface
      ft2232h_rxf_n  : in    std_logic;    -- Rx FIFO Full
      ft2232h_rd_n   : out   std_logic;    -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_txe_n  : in    std_logic;    -- Tx FIFO Empty
      ft2232h_wr_n   : out   std_logic;    -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data   : inOut DataBusType;  -- FIFO Data I/O
      ft2232h_siwu_n : out   std_logic;    -- Flush USB buffer(Send Immediate / WakeUp signal)

      -- Trigger logic
      sample         : in    SampleDataType;
      armed_o        : out   std_logic;
      sampleEnable_o : out   std_logic;

      -- SDRAM interface
      initializing   : out   std_logic;
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs_n     : out   std_logic;
      sdram_ras_n    : out   std_logic;
      sdram_cas_n    : out   std_logic;
      sdram_we_n     : out   std_logic;
      sdram_dqm      : out   std_logic_vector( 1 downto 0);
      sdram_addr     : out   std_logic_vector(12 downto 0);
      sdram_ba       : out   std_logic_vector( 1 downto 0);
      sdram_data     : inout std_logic_vector(15 downto 0)
  );
end entity;

architecture Behavioral of LogicAnalyser is
   -- Sampling
   -- iob_sample -> currentSample -> lastSample
   signal iob_sample                   : SampleDataType;
   signal currentSample                : SampleDataType;
   signal lastSample                   : SampleDataType;

   attribute IOB : string;
   attribute IOB of iob_sample         : signal is "true";

   -- SDRAM interface
   signal cmd_ready                    : std_logic;

   signal cmd_rd                       : std_logic;
   signal cmd_rd_data                  : sdram_phy_DataType := (others => '0');
   signal cmd_rd_data_ready            : std_logic;
   signal cmd_wr_clear                 : std_logic;
   signal cmd_rd_address               : sdram_AddrType := (others => '0');
   signal increment_read_address       : std_logic;

   signal cmd_wr_counter               : sdram_AddrType;

   constant cmd_wr_address_mid         : sdram_AddrType := (sdram_AddrType'left=>'1', others => '0');
   constant cmd_wr_address_max         : sdram_AddrType := (5=>'1', others => '0');

   signal cmd_rd_accepted              : std_logic;
   -- signal initializing                 : std_logic;

   signal lastReadData                 : DataBusType;
   signal lastReadDataValid            : std_logic;

   signal dataOutOred                  : DataBusType;
   signal dataOutTriggerBlock          : DataBusType;

   -- FT2232H Interface
   signal host_receive_data_request    : std_logic;
   signal host_receive_data            : DataBusType;
   signal host_receive_data_available  : std_logic;

   signal host_transmit_data           : DataBusType := (others =>'0');
   signal host_transmit_data_ready     : std_logic;
   signal host_transmit_data_request   : std_logic;

   -- Control iState machine
   type InterfaceState is (
      s_cmd, s_size,
      s_write_control,
      s_lut_config,
      s_read_buffer, s_read_buffer_wait, s_read_buffer_even, s_read_buffer_odd
   );
   signal iState     : InterfaceState:= s_cmd;
   signal nextIState : InterfaceState;

   type TriggerState is (t_idle, t_armed, t_running, t_complete);
   signal tState     : TriggerState := t_idle;
   signal nextTState : TriggerState;

   signal save_command                 : std_logic;
   signal clear_command                : std_logic;
   signal command                      : AnalyserCmdType;

   signal wr_trigger_luts              : std_logic;
   signal trigger_bus_busy             : std_logic;
   signal triggerFound                 : std_logic;

--       7        6        5        4        3        2        1        0
--   +--------+--------------------------------------------------------------+
--   |        |    PRESCALE     |     PRESCALE    | CLEAR  | CLEAR  | START  |
--   |        |    DECADE       |     DIVIDER     | COUNTS |        | ACQ  * |
--   +--------+--------------------------------------------------------------+
-- * self-clearing bit

   signal controlRegister              : std_logic_vector(6 downto 0) := (others => '0');
   alias  controlReg_start_acq         : std_logic        is controlRegister(0);
   alias  controlReg_clear             : std_logic        is controlRegister(1);
   alias  controlReg_clear_counts      : std_logic        is controlRegister(2);
   alias  selectDivider                : std_logic_vector is controlRegister(4 downto 3);
   alias  selectDecade                 : std_logic_vector is controlRegister(6 downto 5);

   signal r_notEmpty                   : std_logic;
   signal r_isEmpty                    : std_logic;
   --signal fifo_full                    : std_logic;
   signal fifo_wr_en                   : std_logic;
   signal r_enable                     : std_logic;
   signal r_clear                      : std_logic;
   signal fifo_data_in                 : SampleDataType;
   signal r_data                       : SampleDataType;

   signal data_count                   : natural range 0 to 255 := 0;
   signal decrement_data_count         : std_logic;
   signal load_data_count              : std_logic;

   signal write_control_reg            : std_logic;

   signal armed                        : std_logic;
   signal sampling                     : std_logic;
   signal capturing                    : std_logic;
--   signal sampleEnable                 : std_logic;

   signal doSample                     : std_logic;

begin

   sampleEnable_o <= doSample;

   Prescaler_inst:
   entity work.Prescaler
   port map (
          clock_100MHz              => clock_100MHz,
          enable                    => sampling,
          doSample                  => doSample,
          selectDivider             => selectDivider,
          selectDecade              => selectDecade
        );

   ft2232h_Interface_inst:
   entity work.ft2232h_Interface
   PORT MAP (
      clock_100MHz                  => clock_100MHz,

      -- FT2232H interface
      ft2232h_rxf_n                 => ft2232h_rxf_n,
      ft2232h_rd_n                  => ft2232h_rd_n,

      ft2232h_txe_n                 => ft2232h_txe_n,
      ft2232h_wr_n                  => ft2232h_wr_n,

      ft2232h_data                  => ft2232h_data,
      ft2232h_siwu_n                => ft2232h_siwu_n,

      -- Receive interface
      host_receive_data_request     => host_receive_data_request,    -- Request data from host
      host_receive_data_available   => host_receive_data_available,  -- Requested data from host is available
      host_receive_data             => host_receive_data,

      -- Send interface
      host_transmit_data_ready      => host_transmit_data_ready,     -- Indicates interface is ready to send data to host
      host_transmit_data_request    => host_transmit_data_request,   -- Send data to host request
      host_transmit_data            => host_transmit_data
   );

   proc_100MHz_to_110MHz:
   process(clock_100MHz,clock_110MHz)

   variable cmd_wr_clear1 : std_logic := '0';
   variable cmd_wr_clear2 : std_logic := '0';

   begin
      if rising_edge(clock_110MHz) then
         cmd_wr_clear1 := cmd_wr_clear;
         r_clear       <= cmd_wr_clear1;
      end if;
   end process;

   r_notEmpty <= not r_isEmpty;

   armed     <= '1' when (tState = t_armed) else '0';
   armed_o   <= armed;

   sampling  <= '1' when (tState = t_running) or (tState= t_armed) else '0';

--   capturing <= '1' when (tState= t_armed) else '0';

   TriggerStateMachine:
   process(clock_100MHz)

   begin
      if rising_edge(clock_100MHz) then

         cmd_wr_clear <= '0';
         if (write_control_reg = '1') then
            controlRegister <= host_receive_data(controlRegister'left downto controlRegister'right);
         end if;

         case (tState) is
            when t_idle =>
               cmd_wr_clear   <= '1';
               cmd_wr_counter <= (others => '0');

               if (controlReg_start_acq = '1') then
                  tState               <= t_armed;
               end if;

            when t_armed =>
               if (doSample = '1') then
                  cmd_wr_counter <= std_logic_vector(unsigned(cmd_wr_counter) + 1);
               end if;
               if (triggerFound = '1') then
                  tState <= t_running;
               end if;

            when t_running =>
               if (cmd_wr_counter = cmd_wr_address_max) then
                  tState <= t_complete;
               end if;

            when t_complete =>
               controlReg_start_acq <= '0';
               if (controlReg_clear = '1') then
                  tState <= t_idle;
               end if;
         end case;
      end if;
   end process;

   ReadAddress_proc:
   process (clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         if (controlReg_clear_counts = '1') then
            cmd_rd_address <= (others => '0');
         elsif (increment_read_address = '1') then
            cmd_rd_address <= std_logic_vector(unsigned(cmd_rd_address) + 1);
         end if;
      end if;
   end process;

   -- Sampled data -> SDRAM
	write_fifo_inst:
   entity work.fifo_2clock
   port map(
      -- 100 MHz clock domain
      w_clock        => clock_100MHz,
		w_clear        => '0',
		w_enable       => doSample,
		w_isFull       => open,
		w_data         => currentSample,

      -- 110 MHz clock domain
      r_clock        => clock_110MHz,
		r_clear        => r_clear,
		r_isEmpty      => r_isEmpty,
		r_enable       => r_enable,
      r_data         => r_data
	);

   SDRAM_Controller_inst :
   entity work.SDRAM_Controller
   port map(
      clock_110MHz      => clock_110MHz,
      clock_110MHz_n    => clock_110MHz_n,

      cmd_wr_clear      => r_clear,
      cmd_wr            => r_notEmpty,
      cmd_wr_data       => r_data,
      cmd_wr_accepted   => r_enable,

      cmd_rd            => cmd_rd,
      cmd_rd_data       => cmd_rd_data,
      cmd_rd_address    => cmd_rd_address,
      cmd_rd_accepted   => cmd_rd_accepted,
      cmd_rd_data_ready => cmd_rd_data_ready,

      initializing      => initializing,

      sdram_clk         => sdram_clk,
      sdram_cke         => sdram_cke,
      sdram_cs_n        => sdram_cs_n,
      sdram_ras_n       => sdram_ras_n,
      sdram_cas_n       => sdram_cas_n,
      sdram_we_n        => sdram_we_n,
      sdram_dqm         => sdram_dqm,
      sdram_ba          => sdram_ba,
      sdram_addr        => sdram_addr,
      sdram_data        => sdram_data
   );

   Sampling_proc:
   process(clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         iob_sample     <= sample;
         currentSample  <= iob_sample;
         lastSample     <= currentSample;
      end if;
   end process;

   TriggerBlock_inst:
   entity TriggerBlock
      port map (
         clock          => clock_100MHz,
         enable         => armed,
         doSample       => doSample,

         currentSample  => currentSample,
         lastSample     => lastSample,
         triggerFound   => triggerFound,

         -- Bus interface (LUTs)
         wr_luts        => wr_trigger_luts,
         dataIn         => host_receive_data,
         rd_luts        => '0',
         dataOut        => open,
         bus_busy       => trigger_bus_busy
        );

   ProcIStateMachineSync:
   process(clock_100MHz)

   begin
      if rising_edge(clock_100MHz) then
         iState <= nextIState;
         if (load_data_count = '1') then
            data_count <= to_integer(unsigned(host_receive_data));
         elsif (decrement_data_count = '1') then
            data_count <= data_count-1;
         end if;
         if (save_command = '1') then
            command <= analyserCmd(host_receive_data);
         elsif (clear_command = '1') then
            command <= ACmd_NOP;
         end if;
      end if;
   end process;

   ProcIStateMachineComb:
   process(iState, command, host_receive_data_available, trigger_bus_busy, data_count, cmd_rd_accepted, cmd_rd_data, host_transmit_data_ready, host_receive_data, cmd_rd_data_ready)

   begin
      -- Default to not accept new data
      host_receive_data_request  <= '0';
      wr_trigger_luts            <= '0';

      -- Default to not reading SDRAM
      cmd_rd                     <= '0';
      host_transmit_data_request <= '0';
      host_transmit_data         <= cmd_rd_data(7 downto 0);

      load_data_count            <= '0';
      decrement_data_count       <= '0';

      save_command               <= '0';
      clear_command              <= '0';

      write_control_reg          <= '0';

      increment_read_address     <= '0';

      nextIState <= iState;

      case (iState) is
         when s_cmd =>
            -- Available to accept commands from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') and (host_receive_data /= C_NOP) then
               -- Save command and start processing
               nextIState    <= s_size;
               save_command  <= '1';
            else
               clear_command <= '1';
            end if;

         when s_size =>
            -- Available to accept command size from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               load_data_count <= '1';
               case (command) is
                  when ACmd_LUT_CONFIG =>
                     nextIState <= s_lut_config;

                  when ACmd_WR_CONTROL =>
                     nextIState <= s_write_control;

                  when ACmd_RD_BUFFER =>
                     nextIState <= s_read_buffer;

                  when others =>
                     nextIState <= s_cmd;
               end case;
            end if;

         when s_write_control =>
            -- Available to accept control register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_control_reg  <= '1';
               nextIState         <= s_cmd;
            end if;

         when s_lut_config =>
            -- Throttle host
            host_receive_data_request  <= not trigger_bus_busy;

            -- Tell trigger to accpet LUT config when available from host
            wr_trigger_luts            <= host_receive_data_available;

            if (host_receive_data_available = '1') then
               if (data_count = 1) then
                  nextIState     <= s_cmd;
                  clear_command <= '1';
               else
                  decrement_data_count <= '1';
               end if;
            end if;

         --===========================================
         -- Due to pipelining in the SDRAM it is
         -- necessary to be careful to only read a single word at a time
         when s_read_buffer =>

            -- Tell SDRAM we want data
            cmd_rd <= '1';

            if (cmd_rd_accepted = '1') then
               -- SDRAM has accepted command but data won't be available for a few clocks
               nextIState <= s_read_buffer_wait;
            end if;

         when s_read_buffer_wait =>

            if (cmd_rd_data_ready = '1') then
               nextIState                  <= s_read_buffer_even;
            end if;

         when s_read_buffer_even =>

            host_transmit_data <= cmd_rd_data(15 downto 8);

            if (host_transmit_data_ready = '1') then
               host_transmit_data_request  <= '1';
               nextIState                  <= s_read_buffer_odd;
            end if;

         when s_read_buffer_odd =>

            host_transmit_data <= cmd_rd_data(7 downto 0);

            if (host_transmit_data_ready = '1') then
               host_transmit_data_request <= '1';
               increment_read_address     <= '1';
               if (data_count = 1) then
                  nextIState              <= s_cmd;
                  clear_command           <= '1';
               else
                  nextIState              <= s_read_buffer;
                  decrement_data_count    <= '1';
               end if;
            end if;
      end case;
   end process;
end Behavioral;