library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

entity SDRAM_Controller is
   port (
      clock_110MHz         : in    std_logic;
      clock_110MHz_n       : in    std_logic;
      cmd_counter_clear    : in    std_logic;

      -- Interface to issue reads or write data
      cmd_wr               : in    std_logic;
      cmd_pretrigger_value : in    std_logic;
      cmd_trigger_value    : in    std_logic;
      cmd_wr_data          : in    sdram_DataType;
      cmd_wr_accepted      : out   std_logic;

      cmd_rd               : in    std_logic;
      cmd_rd_data          : out   sdram_DataType;
      cmd_rd_accepted      : out   std_logic;
      cmd_rd_data_ready    : out   std_logic;

      initializing         : out   std_logic;

      -- SDRAM signals
      sdram_clk            : out   std_logic;
      sdram_cke            : out   std_logic;
      sdram_cs_n           : out   std_logic;
      sdram_ras_n          : out   std_logic;
      sdram_cas_n          : out   std_logic;
      sdram_we_n           : out   std_logic;
      sdram_dqm            : out   sdram_phy_ByteSelType;
      sdram_addr           : out   sdram_phy_AddrType;
      sdram_ba             : out   sdram_phy_BankSelType;
      sdram_data           : inout sdram_phy_DataType
   );
end SDRAM_Controller;

architecture Behavioral of SDRAM_Controller is

   signal sdram_dataOut           : sdram_phy_DataType  := (others => '0');
   signal sdram_dataIn            : sdram_phy_DataType;

   signal rd_address              : sdram_AddrType := (others => '0');
   signal increment_rd_address    : std_logic;

   signal wr_address              : sdram_AddrType := (others => '0');
   signal increment_wr_address    : std_logic;

   ----------------------------------------------------------------
   -- Ensures that outputs and inputs are registered in the IOB.
   -- RAS, CAS, WE, DQM, ADDR, BA = OFF                         
   -- DATA                        = IFF OFF                     
   -- CLK                         = ODDR                        
   -- CS and CKE are static and will not be FFs                 
   ----------------------------------------------------------------
   attribute IOB : string;
   attribute IOB of sdram_cke       : signal is "true";
   attribute IOB of sdram_cs_n      : signal is "true";
   attribute IOB of sdram_ras_n     : signal is "true";
   attribute IOB of sdram_cas_n     : signal is "true";
   attribute IOB of sdram_we_n      : signal is "true";
   attribute IOB of sdram_dqm       : signal is "true";
   attribute IOB of sdram_addr      : signal is "true";
   attribute IOB of sdram_ba        : signal is "true";
   attribute IOB of sdram_dataOut   : signal is "true";
   attribute IOB of sdram_dataIn    : signal is "true";

   signal   refresh_cycle_counter   : unsigned(9 downto 0) := (others => '0'); -- 0 - 1023 Allows pending and forced refresh
   signal   initialisation_counter  : unsigned(4 downto 0) := (others => '0'); -- 0 - 31

   -- Indicate the need to refresh when the counter is near-expired,
   signal pending_refresh : std_logic := '0';

   -- Force a refresh when the counter is expired
   signal forcing_refresh : std_logic := '0';

   -- Stages in the initialisation sequence
   constant do_precharge_count      : natural := 25;
   constant do_refresh1_count       : natural := do_precharge_count + 1;
   constant do_refresh2_count       : natural := do_refresh1_count + 1;
   constant do_mode_reg_count       : natural := do_refresh2_count + 1;
   constant init_complete_count     : natural := do_mode_reg_count + 1;

   -- From page 37 of MT48LC16M16A2 datasheet
   -- Name (Function)       CS# RAS# CAS# WE# DQM  Addr    Data
   -- COMMAND INHIBIT (NOP)  H   X    X    X   X     X       X
   -- NO OPERATION (NOP)     L   H    H    H   X     X       X
   -- ACTIVE                 L   L    H    H   X  Bank/row   X
   -- READ                   L   H    L    H  L/H Bank/col   X
   -- WRITE                  L   H    L    L  L/H Bank/col Valid
   -- BURST TERMINATE        L   H    H    L   X     X     Active
   -- PRECHARGE              L   L    H    L   X   Code      X
   -- AUTO REFRESH           L   L    L    H   X     X       X
   -- LOAD MODE REGISTER     L   L    L    L   X  Op-code    X
   -- Write enable           X   X    X    X   L     X     Active
   -- Write inhibit          X   X    X    X   H     X     High-Z

   type CmdType is (
      C_LOAD_MODE_REG,
      C_REFRESH,
      C_PRECHARGE,
      C_ACTIVE,
      C_WRITE,
      C_READ,
      C_TERMINATE,
      C_NOP
   );

   signal command : CmdType;

   -- Here are the commands mapped to constants
   subtype CmdValue is std_logic_vector(3 downto 0);
   constant CmdValue_NOP           : CmdValue := "0111";
   constant CmdValue_ACTIVE        : CmdValue := "0011";
   constant CmdValue_READ          : CmdValue := "0101";
   constant CmdValue_WRITE         : CmdValue := "0100";
   constant CmdValue_TERMINATE     : CmdValue := "0110";
   constant CmdValue_PRECHARGE     : CmdValue := "0010";
   constant CmdValue_REFRESH       : CmdValue := "0001";
   constant CmdValue_LOAD_MODE_REG : CmdValue := "0000";

   constant BURST_NONE      : sdram_phy_AddrType := "0001000000000";
   constant BURST_LENGTH_1  : sdram_phy_AddrType := "0000000000000";
   constant BURST_LENGTH_2  : sdram_phy_AddrType := "0000000000001";
   constant BURST_LENGTH_4  : sdram_phy_AddrType := "0000000000010";
   constant BURST_LENGTH_8  : sdram_phy_AddrType := "0000000000011";
   constant CAS_1           : sdram_phy_AddrType := "0000000010000";
   constant CAS_2           : sdram_phy_AddrType := "0000000100000";
   constant CAS_3           : sdram_phy_AddrType := "0000000110000";

   -- Latency is 2, don't use burst
   constant MODE_REG        : sdram_phy_AddrType := CAS_3 or BURST_NONE;

   -- Shift-register to indicate when to capture the read value on the SDRAM data bus
   constant READ_LATENCY         : natural := to_integer(unsigned(MODE_REG(5 downto 4)));  -- must agree with MODE_REG value
   signal data_ready_delay       : std_logic_vector(READ_LATENCY-1 downto 0) := (others => '0');

   signal write_pending          : std_logic := '0';
   signal next_write_pending     : std_logic := '0';


   type StateType is (
      s_startup,
      s_refresh,
      s_idle_in_7, s_idle_in_6, s_idle_in_5, s_idle_in_4, s_idle_in_3, s_idle_in_2, s_idle_in_1,
      s_idle,
      s_active,
      s_pre_read1, s_pre_read2, s_read1,  s_read2,  s_read_exit,
      s_pre_write1, s_pre_write2, s_write1, s_write2, s_write3,
      s_precharge
      );

   signal state, next_state : StateType;

   attribute FSM_ENCODING : string;
   attribute FSM_ENCODING of state : signal is "ONE-HOT";

   --  Mapping of Logical address to Row, Column and Bank
   --
   --  2  2  2  2  1  1  1  1  1  1  1  1  1
   --  3  2  1  0  9  8  7  6  5  4  3  2  1  0  9  8  7  6  5  4  3  2  1  0
   -- +-------------------------------------+-----+--------------------------+
   -- |            Row Address              | Bank|      Column Address      | Logical Address
   -- +-------------------------------------+-----+--------------------------+
   --
   --               B  B     A  A  A  A  A  A  A  A  A  A  A  A  A
   --                        1  1  1
   --               1  0     2  1  0  9  8  7  6  5  4  3  2  1  0
   --             +------+ +--------------------------------------+
   --  ACTIVE     | Bank | |            Row Address               | Physical address
   --             +------+ +--------------------------------------+
   --
   --               B  B     A  A  A  A  A  A  A  A  A  A  A  A  A
   --                        1  1  1
   --               1  0     2  1  0  9  8  7  6  5  4  3  2  1  0
   --             +------+ +--------------------------------------+
   -- READ/WRITE  | Bank | | -  -  P  - |     Column Address      | Physical address
   --             +------+ +--------------------------------------+
   --

   -- Bit indexes used when splitting the address into row/colum/bank.
   constant start_of_col        : natural :=  0;
   constant start_of_bank       : natural :=  9;
   constant start_of_row        : natural := 11;

   signal sdram_addr_sm         : sdram_phy_AddrType;
   signal sdram_ba_sm           : sdram_phy_BankSelType;
   --signal sdram_dqm_sm          : sdram_phy_ByteSelType;

   alias  sdram_col_address_sm  : std_logic_vector is sdram_addr_sm(8 downto 0);
   alias  sdram_row_address_sm  : std_logic_vector is sdram_addr_sm(12 downto 0);
   alias  sdram_precharge_sm    : std_logic        is sdram_addr_sm(10);

   -- The incoming addresses are split into these three values
   alias  cmd_wr_col            : std_logic_vector is wr_address(start_of_bank-1  downto start_of_col);
   alias  cmd_wr_bank           : std_logic_vector is wr_address(start_of_row-1   downto start_of_bank);
   alias  cmd_wr_row            : std_logic_vector is wr_address(wr_address'left downto start_of_row);

   alias  cmd_rd_col            : std_logic_vector is rd_address(start_of_bank-1  downto start_of_col);
   alias  cmd_rd_bank           : std_logic_vector is rd_address(start_of_row-1   downto start_of_bank);
   alias  cmd_rd_row            : std_logic_vector is rd_address(rd_address'left downto start_of_row);

   signal cmd_rd_accepted_sm    : std_logic;
   signal cmd_wr_accepted_sm    : std_logic;

   -- Signals to hold the last transaction to allow detection of bank and row changes
   signal last_row              : std_logic_vector(sdram_row_address_sm'range);
   signal last_bank             : sdram_phy_BankSelType;

   -- Control when new transactions are accepted
   signal wr_back_to_back_ok : std_logic;
   signal rd_back_to_back_ok : std_logic;

   -- Signal to control the Hi-Z state of the DQ bus
   signal sdram_dq_hiz          : std_logic;
   signal sdram_dq_hiz_sm       : std_logic;

   signal clear_refresh_counter : std_logic;
   signal rd_data_ready         : std_logic;

   signal sdram_data_90         : sdram_phy_DataType := (others => '0');

   signal initializing_sm       : std_logic;

   -------------------------------------------------------------
   -- Maps readable command names (for debug) to physical values
   --
   function cmd(command : CmdType) return CmdValue is
   begin
      case (command) is
         when C_LOAD_MODE_REG => return CmdValue_LOAD_MODE_REG;
         when C_REFRESH       => return CmdValue_REFRESH;
         when C_PRECHARGE     => return CmdValue_PRECHARGE;
         when C_ACTIVE        => return CmdValue_ACTIVE;
         when C_WRITE         => return CmdValue_WRITE;
         when C_READ          => return CmdValue_READ;
         when C_TERMINATE     => return CmdValue_TERMINATE;
         when C_NOP           => return CmdValue_NOP;
      end case;
   end function;

begin

   initializing <= initializing_sm;
   
   -------------------------------------------------------------------
   -- Forward the SDRAM clock to the SDRAM chip - 180 degress
   -- out of phase with the control signals (ensuring setup and hold)
   --------------------------------------------------------------------
   sdram_clk_forward :
   ODDR2
   generic map(
      ddr_alignment  => "NONE",
      init           => '0',
      srtype         => "SYNC"
   )
   port map (
      r  => '0',
      s  => '0',
      ce => '1',
      d0 => '0',
      d1 => '1',
      c0 => clock_110MHz,
      c1 => clock_110MHz_n,
      q  => sdram_clk
   );

   -- The following have been chosen to favour continuous writes
   --   forcing_refresh > maximum back-to-back sequential writes
   --   pending_refresh < maximum back-to-back sequential writes
   -- This means that refreshes are combined with necessary row/bank changes
   
   forcing_refresh <= refresh_cycle_counter(refresh_cycle_counter'left) and 
                      refresh_cycle_counter(6); 

   Counter_Sync_proc:
   process (clock_110MHz)
   begin
      if rising_edge(clock_110MHz) then
         if (initializing_sm = '0') then
            initialisation_counter      <= (others => '0');
         else
            if (forcing_refresh = '1') then
               initialisation_counter  <= initialisation_counter + 1;
            end if;
         end if;
      
         if (clear_refresh_counter = '1') then
            refresh_cycle_counter      <= (others => '0');
         else
            if (forcing_refresh = '1') then
               refresh_cycle_counter   <= (others => '0');
            else
               refresh_cycle_counter   <= refresh_cycle_counter + 1;
            end if;
         end if;
      
         if ((refresh_cycle_counter(refresh_cycle_counter'left) = '1') or
             (refresh_cycle_counter(refresh_cycle_counter'left-1) = '1')) then
            pending_refresh <= '1';
         end if;
         if (clear_refresh_counter = '1') then
            pending_refresh <= '0';
         end if;
      end if;
      
   end process;

   cmd_rd_accepted <= cmd_rd_accepted_sm;
   cmd_wr_accepted <= cmd_wr_accepted_sm;

   Sdram_Sync_proc1n:
   process (clock_110MHz_n)
   begin
      if rising_edge(clock_110MHz_n) then
         if (rd_data_ready = '1') then
            sdram_data_90  <= sdram_data;
         end if;
      end if;
   end process;

   Sdram_Sync_proc1:
   process (clock_110MHz)
   begin
      if rising_edge(clock_110MHz) then
         cmd_rd_data_ready <= rd_data_ready;
         cmd_rd_data       <= sdram_data_90;
      end if;
   end process;

   Sdram_Sync_proc2:
   process (clock_110MHz)
   
   variable armed : std_logic := '0';
   
   begin
      sdram_cs_n <= '0';
      -- Pipeline signals to/from SDRAM
      if rising_edge(clock_110MHz) then
         state             <= next_state;
         --sdram_cs_n        <= cmd(command)(3);
         sdram_ras_n       <= cmd(command)(2);
         sdram_cas_n       <= cmd(command)(1);
         sdram_we_n        <= cmd(command)(0);
         sdram_addr        <= sdram_addr_sm;
         sdram_ba          <= sdram_ba_sm;
         --sdram_dqm         <= sdram_dqm_sm;

         sdram_dq_hiz      <= sdram_dq_hiz_sm;
         sdram_dataOut     <= cmd_wr_data;

         if (state = s_active) then
            -- Capture the row and bank information for open row
            last_row       <= sdram_row_address_sm;
            last_bank      <= sdram_ba_sm;
         end if;

         -- Update shift registers used to choose when to present data from memory
         data_ready_delay  <= '0' & data_ready_delay(data_ready_delay'left downto 1);
         if (cmd_rd_accepted_sm = '1') then
            data_ready_delay(data_ready_delay'left) <= '1';
         end if;

         -- Present delayed data from memory on command bus
         if (data_ready_delay(0) = '1') then
            rd_data_ready <= '1';
         else
            rd_data_ready <= '0';
         end if;
         
         -- Default DQM (inactive)
         sdram_dqm <= (others => '1');
         
         -- DQM has a fixed 2-cycle latency on read
         -- Assert 2 clocks before data available
         if (data_ready_delay(2) = '1') then
            sdram_dqm <= (others => '0');
         end if;
         
         -- DQM is applied immediately on writes
         if (command = C_WRITE) then
            sdram_dqm <= (others => '0');
         end if;
         
         write_pending <= next_write_pending;

         if (cmd_counter_clear = '1') then
            wr_address        <= (others => '0');
         elsif (increment_wr_address = '1') then
            -- Incremented on writes to the RAM
            wr_address <= std_logic_vector(unsigned(wr_address) + 1);
         end if;

         if (cmd_pretrigger_value = '1') then
            armed := '1';
         elsif (cmd_trigger_value = '1') then
            armed := '0';
         end if;
         
         if (cmd_counter_clear = '1') then
            rd_address        <= (others => '0');
         elsif (increment_rd_address = '1') or 
               ((increment_wr_address = '1') and (armed = '1')) then
            -- Increment on reads from the RAM
            -- OR
            -- Incremented on writes to the RAM while armed
            -- This allows the read address to trail the write address by the pre-trigger amount
            rd_address <= std_logic_vector(unsigned(rd_address) + 1);
         end if;


      end if;
   end process;

   -- 3-state buffers for SDRAM data I/O
   sdram_data <= sdram_dataOut when (sdram_dq_hiz = '0') else (others => 'Z');

   wr_back_to_back_ok <= '1' when ((last_bank = cmd_wr_bank) and (last_row = cmd_wr_row)) else '0';
   rd_back_to_back_ok <= '1' when ((last_bank = cmd_rd_bank) and (last_row = cmd_rd_row)) else '0';

   main_proc:
   process(
      state, initialisation_counter,
      wr_address, rd_address, cmd_wr, cmd_rd, wr_back_to_back_ok, 
      rd_back_to_back_ok, forcing_refresh, pending_refresh, write_pending)

   begin
      ---------------------------------
      -- Default is to do nothing
      ---------------------------------
      command                 <= C_NOP;
      sdram_addr_sm           <= (others => '0');
      sdram_ba_sm             <= (others => '0');
      --sdram_dqm_sm            <= (others => '1');
      sdram_dq_hiz_sm         <= '1';
      initializing_sm            <= '0';
      cmd_rd_accepted_sm      <= '0';
      cmd_wr_accepted_sm      <= '0';
      clear_refresh_counter   <= '0';
      next_state              <= state;
      sdram_cke               <= '1';
      increment_wr_address    <= '0';
      increment_rd_address    <= '0';
      next_write_pending      <= write_pending;

      case state is
         when s_startup =>
            ------------------------------------------------------------------------
            -- This is the initial startup state, where we wait for at least 100us
            -- The data sheet is somewhat confusing.  It says to have CKE low
            -- initially and then sometime within the 100us bring CKE high. Elsewhere
            -- it says CKE may be tied high!  In practice I think is OK to set CKE high
            -- at the start of the initialisation sequence i.e. after clock stable.
            -- This agrees with Figure 36.
            --
            -- The initialisation is sequence is
            --  * Initially de-assert sdram_cke (=low)
            --  * Assert sdram_cke (=high)
            --  * 100us wait while doing 1 or more NOPs
            --  * PRECHARGE ALL command
            --  * Wait tRP doing NOPs. Banks will complete Pre-charge (  wait 2 cycles)
            --  * REFRESH command
            --  * Wait tRFC doing NOPs.
            --  * REFRESH command
            --  * Wait tRFC doing NOPs.
            --  * LOAD_MODE_REG command
            --  * 2 cycles wait
            ------------------------------------------------------------------------
            initializing_sm <= '1';

            -- All the commands during the startup are NOPS, except these
            if (initialisation_counter = do_precharge_count) and (forcing_refresh = '1') then
               -- Ensure all rows are closed
               command          <= C_PRECHARGE;
               sdram_precharge_sm <= '1';  -- all banks
               sdram_ba_sm      <= (others => '0');
               clear_refresh_counter     <= '1';
            elsif (initialisation_counter = do_refresh1_count) and (forcing_refresh = '1') then
               -- Refresh cycle
               command          <= C_REFRESH;
               clear_refresh_counter     <= '1';
            elsif (initialisation_counter = do_refresh2_count) and (forcing_refresh = '1') then
               -- Refresh cycle
               command          <= C_REFRESH;
               clear_refresh_counter     <= '1';
            elsif (initialisation_counter = do_mode_reg_count) and (forcing_refresh = '1') then
               -- Now load the mode register
               command          <= C_LOAD_MODE_REG;
               sdram_addr_sm    <= MODE_REG;
               clear_refresh_counter     <= '1';
            elsif (initialisation_counter = init_complete_count) and (forcing_refresh = '1')  then
               next_state       <= s_refresh;
               clear_refresh_counter     <= '1';
            end if;

         when s_refresh =>
            command              <= C_REFRESH;
            clear_refresh_counter     <= '1';
            next_state           <= s_idle_in_7;

         -- s_idle_in_7, 6, 5,4,3,2,1,s_idle satisfy tRFC > 66 ns (-7E, -75)
         when s_idle_in_7 =>
            next_state <= s_idle_in_6;

         when s_idle_in_6 =>
            next_state <= s_idle_in_5;

         when s_idle_in_5 =>
            next_state <= s_idle_in_4;

         when s_idle_in_4 =>
            next_state <= s_idle_in_3;

         when s_idle_in_3 =>
            next_state <= s_idle_in_2;

         when s_idle_in_2 =>
            next_state <= s_idle_in_1;

         when s_idle_in_1 =>
            next_state <= s_idle;

         when s_idle =>
            -- Priority is to issue a refresh if one is outstanding
            if (pending_refresh = '1') then
              -----------------------------------------------------------------
               -- Start the refresh cycle.
               -- This tasks tRFC (66ns), so 6 idle cycles are needed @ 100MHz
               ----------------------------------------------------------------
               next_state <= s_refresh;
            elsif ((cmd_wr = '1') or (cmd_rd = '1')) then
               ----------------------------------
               -- Start the read or write cycle.
               -- First task is to open the row
               ----------------------------------
               next_state <= s_active;
            end if;

         ---------------------------------------------
         -- Opening the row ready for reads or writes
         ---------------------------------------------
         when s_active =>
            command            <= C_ACTIVE;
            if ((cmd_wr = '1') or (write_pending = '1')) then
               -- Give preference to new writes or a pending one still to do
               next_state           <= s_pre_write1;
               sdram_row_address_sm <= cmd_wr_row;
               sdram_ba_sm          <= cmd_wr_bank;
            else
               next_state           <= s_pre_read1;
               sdram_row_address_sm <= cmd_rd_row;
               sdram_ba_sm          <= cmd_rd_bank;
            end if;

         when s_pre_read1 =>
            -- Satisfies tRD = 20ns = 3cy
            next_state         <= s_pre_read2;

         when s_pre_read2 =>
            -- Satisfies tRD = 20ns = 3cy
            next_state         <= s_read1;

         -----------------------------------------
         -- Processing the read transaction
         -- s_read1-s_read2 satify tRAS and tRP
         -- s_read2 will be a NOP for single-read
         -----------------------------------------
         when s_read1 =>
            -- We know:
            --   rd_back_to_back_ok is invalid
            --   Must do a read
            next_state           <= s_read2;
            command              <= C_READ;
            sdram_ba_sm          <= cmd_rd_bank;
            sdram_col_address_sm <= cmd_rd_col;
            --sdram_dqm_sm         <= (others => '0');
            cmd_rd_accepted_sm   <= '1';
            increment_rd_address <= '1';

         when s_read2 =>
            next_state <= s_read2;

            if ((cmd_rd = '1') and (rd_back_to_back_ok = '1')) then
               -- We can do a read now
               command              <= C_READ;
               sdram_ba_sm          <= cmd_rd_bank;
               sdram_col_address_sm <= cmd_rd_col;
               --sdram_dqm_sm         <= (others => '0');
               cmd_rd_accepted_sm   <= '1';
               increment_rd_address <= '1';
            end if;

            if (forcing_refresh = '1') then
               -- Must do a refresh next
               next_state <= s_read_exit;
            end if;
            
            if ((cmd_rd = '1') and (rd_back_to_back_ok = '0')) then
               -- Must change row/bank for read
               next_state <= s_read_exit;
            end if;

            if ((cmd_wr = '1') and (cmd_rd = '0')) then
               -- Might as well do the read next
               next_state <= s_read_exit;
            end if;

         when s_read_exit =>
            next_state   <= s_precharge;

         -----------------------------------------------------
         -- This piplines the writes from the FIFO
         -----------------------------------------------------
         when s_pre_write1 =>
            -- Satisfies tRD = 20ns = 2cy
            next_state         <= s_pre_write2;
         
         when s_pre_write2 =>
            -- Satisfies tRD = 20ns = 2cy
            next_state         <= s_write1;
            if (write_pending = '0') then
               -- Get new data ahead of write as needed
               cmd_wr_accepted_sm   <= '1';
               next_write_pending   <= '1';
            end if;

         -----------------------------------------------------
         -- Processing the write transaction
         -- s_write1-s_write2-s_write3 satify tRAS and tRP
         -- s_write2, s_write3 will be a NOPs for single-write
         -----------------------------------------------------
         when s_write1 =>
            next_state              <= s_write2;

            -- We know:
            --    write_pending = '1'
            --    wr_back_to_back_ok is invalid

            -- Do write now
            command                 <= C_WRITE;
            sdram_ba_sm             <= cmd_wr_bank;
            sdram_col_address_sm    <= cmd_wr_col;
            --sdram_dqm_sm            <= (others => '0');
            sdram_dq_hiz_sm         <= '0';
            increment_wr_address    <= '1';
            next_write_pending      <= '0';

            if (cmd_wr = '1') then
               -- Always accept a word to write if available
               cmd_wr_accepted_sm   <= '1';
               next_write_pending   <= '1';
            end if;

         when s_write2 =>
            next_state <= s_write3;

            -- Situation:
            --    We may have some data (write_pending)
            --    wr_back_to_back_ok is valid
            if (write_pending = '1') and (wr_back_to_back_ok = '1') then
               -- Do write now
               command                 <= C_WRITE;
               sdram_ba_sm             <= cmd_wr_bank;
               sdram_col_address_sm    <= cmd_wr_col;
               --sdram_dqm_sm            <= (others => '0');
               sdram_dq_hiz_sm         <= '0';
               increment_wr_address    <= '1';
               next_write_pending      <= '0';

               if (cmd_wr = '1') then
                  -- Accept new data if available
                  cmd_wr_accepted_sm   <= '1';
                  next_write_pending   <= '1';
               end if;
            end if;

            if (cmd_wr = '1') and (write_pending = '0') then
               -- Accept new data if available and needed
               cmd_wr_accepted_sm      <= '1';
               next_write_pending      <= '1';
            end if;

         when s_write3 =>
            next_state <= s_write3;

            -- Situation:
            --    We may have some data (write_pending)
            --    wr_back_to_back_ok is valid
            if (write_pending = '1') and (wr_back_to_back_ok = '1') then
               -- Do write now
               command                 <= C_WRITE;
               sdram_ba_sm             <= cmd_wr_bank;
               sdram_col_address_sm    <= cmd_wr_col;
               --sdram_dqm_sm            <= (others => '0');
               sdram_dq_hiz_sm         <= '0';
               increment_wr_address    <= '1';
               next_write_pending      <= '0';

               if (cmd_wr = '1') then
                  -- Accept new data if available
                  cmd_wr_accepted_sm   <= '1';
                  next_write_pending   <= '1';
               end if;
            end if;

            if (cmd_wr = '1') and (write_pending = '0') then
               -- Accept new data if available and needed
               cmd_wr_accepted_sm      <= '1';
               next_write_pending      <= '1';
            end if;

            if (forcing_refresh = '1') then
               -- Must do a refresh!
               next_state   <= s_precharge;
            end if;

            if ((write_pending = '0') and (cmd_rd = '1')) then
               -- Might as well do the read
               next_state   <= s_precharge;
            end if;

            if (wr_back_to_back_ok = '0') then
               -- Must change row/bank for this write
               next_state   <= s_precharge;
            end if;

            if ((write_pending = '0') and (pending_refresh = '1')) then
               -- Might as well do an early refresh
               next_state   <= s_precharge;
            end if;

         -----------------------------------------------
         -- Closing the row off (this closes all banks)
         -----------------------------------------------
         when s_precharge =>
            command            <= C_PRECHARGE;
            next_state         <= s_idle_in_1;
            sdram_precharge_sm <= '1';  -- all banks

      end case;
   end process;
end Behavioral;