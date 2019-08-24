library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

entity LogicAnalyser is
   port (
      clock_100MHz      : in    std_logic;
      clock_110MHz      : in    std_logic;
      clock_110MHz_n    : in    std_logic;

      -- FT2232 Interface
      ft2232h_rxf_n     : in    std_logic;    -- Rx FIFO Full
      ft2232h_rd_n      : out   std_logic;    -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_txe_n     : in    std_logic;    -- Tx FIFO Empty
      ft2232h_wr_n      : out   std_logic;    -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data      : inOut DataBusType;  -- FIFO Data I/O
      ft2232h_siwu_n    : out   std_logic;    -- Flush USB buffer(Send Immediate / WakeUp signal)

      -- Trigger logic
      sample            : in    SampleDataType;
      armed_o           : out   std_logic;
      sampling_o        : out   std_logic;
      doSample_o        : out   std_logic;

      -- SDRAM interface
      initializing      : out   std_logic;
      sdram_clk         : out   std_logic;
      sdram_cke         : out   std_logic;
      sdram_cs_n        : out   std_logic;
      sdram_ras_n       : out   std_logic;
      sdram_cas_n       : out   std_logic;
      sdram_we_n        : out   std_logic;
      sdram_dqm         : out   std_logic_vector( 1 downto 0);
      sdram_addr        : out   std_logic_vector(12 downto 0);
      sdram_ba          : out   std_logic_vector( 1 downto 0);
      sdram_data        : inout std_logic_vector(15 downto 0)
  );
end entity;

architecture Behavioral of LogicAnalyser is

   attribute ASYNC_REG                   : string;
   attribute IOB                         : string;

   -- SDRAM FIFO data contains 2 flags + sample value
   signal write_fifo_din                 : std_logic_vector(SampleDataType'left+2 downto 0) := (others => '0');
   signal write_fifo_dout                : std_logic_vector(SampleDataType'left+2 downto 0) := (others => '0');

   alias  preTrigger_sample              : std_logic      is write_fifo_din(SampleDataType'left+2);
   alias  trigger_sample                 : std_logic      is write_fifo_din(SampleDataType'left+1);
   alias  currentSample                  : SampleDataType is write_fifo_din(SampleDataType'left downto 0);

   -- Sampling
   -- iob_sample -> currentSample -> lastSample
   signal iob_sample                     : SampleDataType := (others => '0');
   signal lastSample                     : SampleDataType := (others => '0');

   attribute IOB of iob_sample           : signal is "true";

   attribute ASYNC_REG of currentSample  : signal is "true";
   attribute ASYNC_REG of lastSample     : signal is "true";

   -- SDRAM interface
   signal cmd_ready                      : std_logic      := '0';

   signal sdram_counter_clear            : std_logic      := '0';
   signal sdram_rd                       : std_logic      := '0';
   signal sdram_rd_data_ready            : std_logic      := '0';
   signal sdram_rd_data                  : sdram_phy_DataType := (others => '0');

   -- Count of captured data
   signal capture_counter                : sdram_AddrType := (others => '0');

   -- Required pre-trigger captured data
   signal preTrigger_amount              : sdram_AddrType := (others => '0');

   -- Required captured data
   signal capture_amount                 : sdram_AddrType := (others => '0');

   signal sdram_rd_accepted              : std_logic      := '0';

   signal lastReadData                   : DataBusType    := (others => '0');
   signal lastReadDataValid              : std_logic      := '0';

   signal dataOutOred                    : DataBusType    := (others => '0');
   signal dataOutTriggerBlock            : DataBusType    := (others => '0');

   -- FT2232H Interface
   signal host_receive_data_request      : std_logic      := '0';
   signal host_receive_data              : DataBusType    := (others => '0');
   signal host_receive_data_available    : std_logic      := '0';

   signal host_transmit_data             : DataBusType    := (others =>'0');
   signal host_transmit_data_ready       : std_logic      := '0';
   signal host_transmit_data_request     : std_logic      := '0';

   signal read_fifo_data                 : DataBusType    := (others =>'0');

   -- Control iState machine
   type InterfaceState is (
      s_cmd,            -- Waiting for command value
      s_size,           -- Getting size of read/write
      s_write_control,  -- Writng control register
      s_write_pretrig1, -- Writing 24-bit pre-trig value
      s_write_pretrig2,
      s_write_pretrig3,
      s_write_capture1, -- Writing 24-bit capture value
      s_write_capture2,
      s_write_capture3,
      s_lut_config,     -- Writing LUT config data
      s_read_version,   -- Read design version
      s_read_buffer,    -- Reading SDRAM
      s_read_status     -- Reading Status values
   );
   signal iState                         : InterfaceState := s_cmd;
   signal nextIState                     : InterfaceState := s_cmd;

   type TriggerState is (
      t_idle,        -- Idle (not capturing)
      t_preTrig,     -- Capturing data to create pre-trig data
      t_armed,       -- Looking for trigger while capturing
      t_running,     -- Capturing after trigger
      t_complete     -- Buffer filled (not capturing)
   );

   signal tState                         : TriggerState := t_idle;
   signal nextTState                     : TriggerState := t_idle;

   signal save_command                   : std_logic    := '0';
   signal clear_command                  : std_logic    := '0';
   signal command                        : AnalyserCmdType;

   signal wr_trigger_luts                : std_logic    := '0';
   signal trigger_bus_busy               : std_logic    := '0';
   signal triggerFound                   : std_logic    := '0';

--       7        6       5      4       3       2        1       0
--   +-------+-------+-------+-------+-------+-------+-------+-------+
--   |               |    PRESCALE   |    PRESCALE   | CLEAR | START |
--   |               |     DECADE    |    DIVIDER    |   *   | ACQ * |
--   +-------+-------+-------+-------+-------+-------+-------+-------+
--     * self-clearing bits

   signal controlRegister                : std_logic_vector(5 downto 0) := (others => '0');
   alias  controlReg_start_acq           : std_logic        is controlRegister(0);
   alias  controlReg_clear               : std_logic        is controlRegister(1);
   alias  selectDivider                  : std_logic_vector is controlRegister(3 downto 2);
   alias  selectDecade                   : std_logic_vector is controlRegister(5 downto 4);

   signal sdram_wr                       : std_logic := '0';
   signal r_isEmpty                      : std_logic := '0';
   signal fifo_wr_en                     : std_logic := '0';
   signal sdram_wr_accepted              : std_logic := '0';
   signal fifo_data_in                   : SampleDataType := (others => '0');
   alias  sdram_wr_data                  : SampleDataType is write_fifo_dout(SampleDataType'left downto 0);

   signal data_count                     : natural range 0 to 255 := 0;
   signal decrement_data_count           : std_logic := '0';
   signal load_data_count                : std_logic := '0';

   signal write_control_reg              : std_logic := '0';

   signal armed                          : std_logic := '0';
   signal sampling                       : std_logic := '0';

   signal doSample                       : std_logic;

   signal read_fifo_empty                : std_logic := '0';
   signal read_fifo_near_full            : std_logic := '0';
   signal read_fifo_full                 : std_logic := '0';
   signal read_fifo_rd_en                : std_logic := '0';

   signal read_sdram                     : std_logic := '0';
   signal read_sdram1                    : std_logic := '0';
   signal read_sdram2                    : std_logic := '0';

   attribute ASYNC_REG of read_sdram     : signal is "TRUE";
   attribute ASYNC_REG of read_sdram1    : signal is "TRUE";
   attribute ASYNC_REG of read_sdram2    : signal is "TRUE";

   signal clear_counter                  : std_logic := '0';
   signal clear_counter1                 : std_logic := '0';
   signal clear_counter2                 : std_logic := '0';

   attribute ASYNC_REG of clear_counter  : signal is "TRUE";
   attribute ASYNC_REG of clear_counter1 : signal is "TRUE";
   attribute ASYNC_REG of clear_counter2 : signal is "TRUE";

   signal write_pretrig_high             : std_logic := '0';
   signal write_pretrig_mid              : std_logic := '0';
   signal write_pretrig_low              : std_logic := '0';
   signal write_capture_high             : std_logic := '0';
   signal write_capture_mid              : std_logic := '0';
   signal write_capture_low              : std_logic := '0';

begin

   -- Port shadows
   armed_o     <= armed;
   sampling_o  <= sampling;
   doSample_o  <= doSample;

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

   sdram_wr <= not r_isEmpty;

   -- Mark sample as pre-trigger threshold
   preTrigger_sample <= '1' when (capture_counter = preTrigger_amount) else '0';

   -- Mark this sample as trigger sample
   trigger_sample    <= '1' when (triggerFound = '1') else '0';

   CaptureStateMachine:
   process(clock_100MHz)

   variable next_count : sdram_AddrType;
   
   begin
      if rising_edge(clock_100MHz) then

         clear_counter  <= '0';
         sampling       <= '0';
         armed          <= '0';

         if (write_control_reg = '1') then
            controlRegister <= host_receive_data(controlRegister'left downto controlRegister'right);
         end if;

         if (write_pretrig_high = '1') then
            preTrigger_amount(preTrigger_amount'left downto 16) <= host_receive_data(preTrigger_amount'left-16 downto 0);
         end if;

         if (write_pretrig_mid  = '1') then
            preTrigger_amount(15 downto 8) <= host_receive_data;
         end if;

         if (write_pretrig_low  = '1') then
            preTrigger_amount(7 downto 0) <= host_receive_data;
         end if;

         if (write_capture_high = '1') then
            capture_amount(capture_amount'left downto 16) <= host_receive_data(capture_amount'left-16 downto 0);
         end if;

         if (write_capture_mid  = '1') then
            capture_amount(15 downto 8) <= host_receive_data;
         end if;

         if (write_capture_low  = '1') then
            capture_amount(7 downto 0) <= host_receive_data;
         end if;

         case (tState) is
            when t_idle =>
               -- Idle
               capture_counter  <= (others => '0');

               if (controlReg_start_acq = '1') then
                  clear_counter <= '1';
                  tState        <= t_preTrig;
               end if;

            when t_preTrig =>
               -- Capturing data to create minimum pre-trig data

               -- Write pointer advances
               -- Read pointer is held so read pointer trails write pointer
               sampling  <= '1';

               if (doSample = '1') then
                  -- Count pre-trigger capture
                  next_count := std_logic_vector(unsigned(capture_counter) + 1);
                  capture_counter <= next_count;
                  if (next_count = preTrigger_amount) then
                     -- End of pre-trigger capture
                     tState <= t_armed;
                  end if;
               end if;

            when t_armed =>
               -- Looking for trigger while capturing data
               -- Write and read pointers are advanced to keep
               -- current pre-trigger and capture points in sync
               -- Capture count is held at pre-trigger value
               armed     <= '1';
               sampling  <= '1';
               if (doSample = '1') then
                  if (triggerFound = '1') then
                     -- Found trigger
                     tState <= t_running;
                  end if;
               end if;

            when t_running =>
               -- Capturing after trigger
               -- Write and read pointers are advanced to keep
               -- current pre-trigger and capture points in sync

               sampling <= '1';
               if (doSample = '1') then
                  -- Count post-trigger capture
                  capture_counter <= std_logic_vector(unsigned(capture_counter) + 1);
                  if (capture_counter = capture_amount) then
                     -- Captured required amount of data
                     tState <= t_complete;
                  end if;
               end if;

            when t_complete =>
               -- Buffer filled (not currently capturing)
               controlReg_start_acq <= '0';
               if (controlReg_clear = '1') then
                  tState           <= t_idle;
                  controlReg_clear <= '0';
               end if;
         end case;
      end if;
   end process;

   -- SDRAM -> Read path
	read_fifo_inst:
   entity work.read_fifo
   port map(
		rst            => sdram_counter_clear,

      -- 110 MHz clock domain (SDRAM)
      wr_clk         => clock_110MHz,
		wr_en          => sdram_rd_data_ready,
		full           => read_fifo_full,
      prog_full      => read_fifo_near_full,
		din            => sdram_rd_data,

      -- 100 MHz clock domain (Read data path)
      rd_clk         => clock_100MHz,
		empty          => read_fifo_empty,
		rd_en          => read_fifo_rd_en,
      dout           => read_fifo_data
	);

   -- Sampled data -> SDRAM
	write_fifo_inst:
   entity work.write_fifo
   port map(
		rst            => sdram_counter_clear,

      -- 100 MHz clock domain (Sample data)
      wr_clk         => clock_100MHz,
		wr_en          => doSample,
		full           => open,
		din            => write_fifo_din,

      -- 110 MHz clock domain (SDRAM)
      rd_clk         => clock_110MHz,
		empty          => r_isEmpty,
      almost_empty   => open,
      valid          => open,
		rd_en          => sdram_wr_accepted,
      dout           => write_fifo_dout
	);

   -- Read from SDRAM -> FIFO
   -- This crosses clock domains so needs sync
   fifo_sdramProc:
   process(clock_110MHz)
   begin
      if rising_edge(clock_110MHz) then
         read_sdram1   <= read_sdram;
         read_sdram2   <= read_sdram1;
         sdram_rd      <= read_sdram2 and not read_fifo_near_full;

         clear_counter1       <= clear_counter;
         clear_counter2       <= clear_counter1;
         sdram_counter_clear  <= clear_counter2;
      end if;
   end process;

   SDRAM_Controller_inst :
   entity work.SDRAM_Controller
   port map(
      clock_110MHz         => clock_110MHz,
      clock_110MHz_n       => clock_110MHz_n,

      initializing         => initializing,
      cmd_counter_clear    => sdram_counter_clear,

      -- Write port
      cmd_wr               => sdram_wr,
      cmd_pretrigger_value => write_fifo_dout(SampleDataType'left+2),
      cmd_trigger_value    => write_fifo_dout(SampleDataType'left+1),
      cmd_wr_data          => write_fifo_dout(SampleDataType'left downto 0),
      cmd_wr_accepted      => sdram_wr_accepted,

      -- Read port
      cmd_rd               => sdram_rd,
      cmd_rd_data          => sdram_rd_data,
      cmd_rd_accepted      => sdram_rd_accepted,
      cmd_rd_data_ready    => sdram_rd_data_ready,

      -- SDRAM I/O
      sdram_clk            => sdram_clk,
      sdram_cke            => sdram_cke,
      sdram_cs_n           => sdram_cs_n,
      sdram_ras_n          => sdram_ras_n,
      sdram_cas_n          => sdram_cas_n,
      sdram_we_n           => sdram_we_n,
      sdram_dqm            => sdram_dqm,
      sdram_ba             => sdram_ba,
      sdram_addr           => sdram_addr,
      sdram_data           => sdram_data
   );

   Sampling_proc:
   process(clock_100MHz)
   begin
      if rising_edge(clock_100MHz) then
         iob_sample     <= sample;
         if (doSample = '1') then
            currentSample  <= iob_sample;
            lastSample     <= currentSample;
         end if;
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
   process(
      iState,
      command,
      trigger_bus_busy,
      read_fifo_data, read_fifo_empty,
      host_receive_data_available, host_transmit_data_ready, host_receive_data,
      controlRegister, tState,
      data_count
   )

   begin
      -- Default to not accept new data
      host_receive_data_request  <= '0';
      wr_trigger_luts            <= '0';

      -- Default to not reading SDRAM
      host_transmit_data_request <= '0';

      -- Default connect data from read_fifo to FT2232
      host_transmit_data         <= read_fifo_data;

      load_data_count            <= '0';
      decrement_data_count       <= '0';

      save_command               <= '0';
      clear_command              <= '0';

      write_control_reg          <= '0';

      read_sdram                 <= '0';
      read_fifo_rd_en            <= '0';

      nextIState <= iState;

      write_capture_high         <= '0';
      write_capture_mid          <= '0';
      write_capture_low          <= '0';

      write_pretrig_high         <= '0';
      write_pretrig_mid          <= '0';
      write_pretrig_low          <= '0';

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

                  when ACmd_WR_PRETRIG =>
                     nextIState <= s_write_pretrig1;

                  when ACmd_WR_CAPTURE =>
                     nextIState <= s_write_capture1;

                  when ACmd_RD_BUFFER =>
                     nextIState <= s_read_buffer;

                  when ACmd_RD_STATUS =>
                     nextIState <= s_read_status;

                  when ACmd_RD_VERSION =>
                     nextIState <= s_read_version;

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

         when s_write_pretrig1 =>
            -- Available to accept pretrig register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_pretrig_low    <= '1';
               nextIState           <= s_write_pretrig2;
            end if;

         when s_write_pretrig2 =>
            -- Available to accept pretrig register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_pretrig_mid    <= '1';
               nextIState           <= s_write_pretrig3;
            end if;

         when s_write_pretrig3 =>
            -- Available to accept pretrig register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_pretrig_high   <= '1';
               nextIState           <= s_cmd;
            end if;

         when s_write_capture1 =>
            -- Available to accept capture register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_capture_low    <= '1';
               nextIState           <= s_write_capture2;
            end if;

         when s_write_capture2 =>
            -- Available to accept capture register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_capture_mid    <= '1';
               nextIState           <= s_write_capture3;
            end if;

         when s_write_capture3 =>
            -- Available to accept capture register value from host
            host_receive_data_request <= '1';

            if (host_receive_data_available = '1') then
               write_capture_high   <= '1';
               nextIState           <= s_cmd;
            end if;

         when s_lut_config =>
            -- Throttle host
            host_receive_data_request  <= not trigger_bus_busy;

            -- Tell trigger to accept LUT config when available from host
            wr_trigger_luts            <= host_receive_data_available;

            if (host_receive_data_available = '1') then
               if (data_count = 1) then
                  nextIState    <= s_cmd;
                  clear_command <= '1';
               else
                  decrement_data_count <= '1';
               end if;
            end if;

         when s_read_status =>

--       7        6       5      4       3       2        1       0
--   +-------+-------+-------+-------+-------+-------+-------+-------+
--   |                                       |         State         |
--   |                                       |                       |
--   +-------+-------+-------+-------+-------+-------+-------+-------+

            host_transmit_data <=
               "00000"&
               std_logic_vector(to_unsigned(TriggerState'pos(tState),3));

            -- Check FT2232 is ready
            if (host_transmit_data_ready = '1') then
               -- Send data and advance FIFO
               host_transmit_data_request <= '1';
               nextIState                 <= s_cmd;
               clear_command              <= '1';
            end if;


         when s_read_version =>

--       7        6       5      4       3       2        1       0
--   +-------+-------+-------+-------+-------+-------+-------+-------+
--   |       version                                                 |
--   |                                                               |
--   +-------+-------+-------+-------+-------+-------+-------+-------+

            host_transmit_data <= "00000001";

            -- Check FT2232 is ready
            if (host_transmit_data_ready = '1') then
               -- Send data and advance FIFO
               host_transmit_data_request <= '1';
               nextIState                 <= s_cmd;
               clear_command              <= '1';
            end if;

         --======================================================================
         -- The read_fifo controls reading from the SDRAM
         -- It has sufficient slack to accommodate the read latency of the SDRAM
         when s_read_buffer =>

            -- Tell SDRAM we want data (throttled by read_fifo)
            read_sdram <= '1';

            -- Check FT2232 is ready and there is data from the SDRAM (via FIFO)
            if (host_transmit_data_ready = '1') and (read_fifo_empty = '0') then
               -- Send data and advance FIFO
               host_transmit_data_request <= '1';
               -- Advance FIFO
               read_fifo_rd_en            <= '1';
               if (data_count = 1) then
                  -- Read required bytes
                  nextIState              <= s_cmd;
                  clear_command           <= '1';
               else
                  -- More bytes to do
                  nextIState              <= s_read_buffer;
                  decrement_data_count    <= '1';
               end if;
            end if;
      end case;
   end process;
end Behavioral;