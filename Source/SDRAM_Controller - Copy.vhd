----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Create Date:    14:09:12 09/15/2013 
-- Module Name:    SDRAM_Controller - Behavioral 
-- Description:    Simple SDRAM controller for a Micron 48LC16M16A2-7E
--                 or Micron 48LC4M16A2-7E @ 100MHz      
-- Revision: 
-- Revision 0.1 - Initial version
-- Revision 0.2 - Removed second clock signal that isn't needed.
-- Revision 0.3 - Added back-to-back reads and writes.
-- Revision 0.4 - Allow refeshes to be delayed till next PRECHARGE is issued,
--                Unless they get really, really delayed. If a delay occurs multiple
--                refreshes might get pushed out, but it will have avioded about 
--                50% of the refresh overhead
-- Revision 0.5 - Add more paramaters to the design, allowing it to work for both the 
--                Papilio Pro and Logi-Pi
-- Revision 0.6 - Fixed bugs in back-to-back reads (thanks Scotty!)
--
-- Worst case performance (single accesses to different rows or banks) is: 
-- Writes 16 cycles = 6,250,000 writes/sec = 25.0MB/s (excluding refresh overhead)
-- Reads  17 cycles = 5,882,352 reads/sec  = 23.5MB/s (excluding refresh overhead)
--
-- For 1:1 mixed reads and writes into the same row it is around 88MB/s 
-- For reads or wries to the same it is can be as high as 184MB/s 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.LogicAnalyserPackage.all;

library unisim;
use unisim.vcomponents.all;

entity SDRAM_Controller is
   Port ( 
      clock             : in  std_logic;
      reset             : in  std_logic;

      -- Interface to issue reads or write data
      cmd_ready         : out std_logic;          -- '1' when a new command will be acted on
      cmd_enable        : in  std_logic;          -- Set to '1' to issue new command (only acted on when C_read = '1')
      cmd_wr            : in  std_logic;          -- Is this a write?
      cmd_address       : in  sdram_AddrType;     -- address to read/write
      cmd_data_in       : in  sdram_DataType;     -- data for the write command
                                                  
      data_out          : out sdram_phy_DataType; -- word read from SDRAM
      data_out_ready    : out std_logic;          -- is new data ready?

      -- SDRAM signals 
      sdram_clk         : out   std_logic;
      sdram_cke         : out   std_logic;
      sdram_cs          : out   std_logic;
      sdram_ras_n       : out   std_logic;
      sdram_cas_n       : out   std_logic;
      sdram_we_n        : out   std_logic;
      sdram_dqm         : out   sdram_phy_ByteSelType;
      sdram_addr        : out   sdram_phy_AddrType;
      sdram_ba          : out   sdram_phy_BankSelType;
      sdram_data        : inout sdram_phy_DataType
   );
end SDRAM_Controller;

architecture Behavioral of SDRAM_Controller is

   constant startup_cycles     : natural := 10100; -- 100us, plus a little more
   constant cycles_per_refresh : natural := (64000 * 100)/4196 - 1;

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
--      C_UNSELECTED
   );
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
--   constant CmdValue_UNSELECTED    : CmdValue := "1000";

   constant BURST_NONE      : sdram_phy_AddrType := "0001000000000";
   constant BURST_LENGTH_1  : sdram_phy_AddrType := "0000000000000";
   constant BURST_LENGTH_2  : sdram_phy_AddrType := "0000000000001";
   constant BURST_LENGTH_4  : sdram_phy_AddrType := "0000000000010";
   constant BURST_LENGTH_8  : sdram_phy_AddrType := "0000000000011";
   constant CAS_1           : sdram_phy_AddrType := "0000000010000";
   constant CAS_2           : sdram_phy_AddrType := "0000000100000";
   constant CAS_3           : sdram_phy_AddrType := "0000000110000";
   
   constant MODE_REG        : sdram_phy_AddrType := CAS_2 or BURST_NONE;
   
   signal iob_cke           : std_logic;
   signal command           : CmdType;
   signal iob_command       : CmdValue;
   signal iob_address       : sdram_phy_AddrType;
   signal iob_data          : sdram_phy_DataType;
   signal iob_bank          : sdram_phy_BankSelType;
      
   signal sdram_din         : sdram_phy_DataType;
   signal captured_data     : sdram_phy_DataType;
   
   attribute IOB : string;
   attribute IOB of iob_cke         : signal is "true";
   attribute IOB of iob_command     : signal is "true";
   attribute IOB of iob_address     : signal is "true";
   attribute IOB of iob_data        : signal is "true";
   attribute IOB of captured_data   : signal is "true";
   
   type StateType is (s_startup,
                      s_idle_in_6, s_idle_in_5, s_idle_in_4, s_idle_in_3, s_idle_in_2, s_idle_in_1,
                      s_idle,
                      s_open_in_2, s_open_in_1,
--                      s_write_N, s_write_2, s_write_N,
                      s_write, s_write_exit,
--                      s_read_1,  s_read_2,  s_read_3,  s_read_4,  
                      s_read, s_read_exit,  
                      s_precharge
                      );

   signal state           : StateType;
   attribute FSM_ENCODING : string;
   attribute FSM_ENCODING of state : signal is "ONE-HOT";
   
   -- Dual purpose counter, it counts up during the startup phase, then is used to trigger refreshes.
   constant startup_refresh_max   : unsigned(13 downto 0) := (others => '1');  
   signal   startup_refresh_count : unsigned(13 downto 0) := startup_refresh_max-to_unsigned(startup_cycles,14);

   -- Logic to decide when to refresh
   signal pending_refresh  : std_logic;
   signal forcing_refresh  : std_logic;

   --   1  1  1  1  1  1  1  1  1  
   --   9  8  7  6  5  4  3  2  1  0  9  8  7  6  5  4  3  2  1  0  
   -- +--------------------------------+-----+--------------------+
   -- |        Row Address             | Bank|   Column Address   | Logical Address
   -- +--------------------------------+-----+--------------------+
   --
   --               B  B     A  A  A  A  A  A  A  A  A  A  A  A  A  
   --                        1  1  1 
   --               1  0     2  1  0  9  8  7  6  5  4  3  2  1  0 
   --             +------+ +--------------------------------------+
   --  ACTIVE     | Bank | | -  - |           Row Address         | Physical address
   --             +------+ +--------------------------------------+
   -- 
   --               B  B     A  A  A  A  A  A  A  A  A  A  A  A  A  
   --                        1  1  1
   --               1  0     2  1  0  9  8  7  6  5  4  3  2  1  0
   --             +------+ +--------------------------------------+
   -- READ/WRITE  | Bank | | -  -  P  -  -|   Column Address   | -| Physical address
   --             +------+ +--------------------------------------+
   --
   constant PRECHARGE_ON   : sdram_phy_AddrType := (10 => '1', others => '0');
   
   -- Bit indexes used when splitting the address into row/colum/bank.
   constant start_of_col   : natural := 0;
   constant start_of_bank  : natural := 7;
   constant start_of_row   : natural := 9;
   
   -- The incoming address is split into these three values
   alias   addr_col        : std_logic_vector(7 downto 1)  is cmd_address(start_of_bank-1  downto start_of_col);
   alias   addr_bank       : sdram_phy_BankSelType         is cmd_address(start_of_row-1   downto start_of_bank);
   alias   addr_row        : std_logic_vector(10 downto 0) is cmd_address(cmd_address'left downto start_of_row);
   
   -- Signals to hold the requested transaction before it is completed
   signal save_wr          : std_logic;
   signal save_row         : std_logic_vector(addr_row'left downto addr_row'right);
   signal save_bank        : sdram_phy_BankSelType;
   signal save_col         : std_logic_vector(addr_col'left downto addr_col'right);
   signal save_data_in     : sdram_phy_DataType;
   alias  iob_col_address  : std_logic_vector is iob_address(save_col'left downto save_col'right);
   alias  iob_row_address  : std_logic_vector is iob_address(save_row'left downto save_row'right);

   -- Control when new transactions are accepted
   signal ready_for_new    : std_logic;
   signal got_transaction  : std_logic;
   signal can_back_to_back : std_logic;

   -- signal to control the Hi-Z state of the DQ bus
   signal iob_dq_hiz       : std_logic := '1';

   -- Shift-register to indicate when to read the data off of the bus
   signal data_ready_delay : std_logic_vector( 3 downto 0);   
   
   -- Inverted clock
   signal   clock_n : std_logic;
   
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
   -- Indicate the need to refresh when the counter is 2048,
   -- Force a refresh when the counter is 4096 - (if a refresh is forced, 
   -- multiple refreshes will be forced until the counter is below 2048)
   pending_refresh <= startup_refresh_count(11);
   forcing_refresh <= startup_refresh_count(12);

   -- Tell the outside world when we can accept a new transaction;
   cmd_ready <= ready_for_new;
      
   -------------------------------------------------------------------
   -- Forward the SDRAM clock to the SDRAM chip - 180 degress 
   -- out of phase with the control signals (ensuring setup and hold)
  --------------------------------------------------------------------
sdram_clk_forward : ODDR2
   generic map(
      DDR_ALIGNMENT  => "NONE", 
      INIT           => '0', 
      SRTYPE         => "SYNC"
   )
   port map (
      Q  => sdram_clk, 
      C0 => clock, 
      C1 => clock_n, 
      CE => '1', 
      R  => '0', 
      S  => '0', 
      D0 => '0', 
      D1 => '1'
   );

   clock_n <= not clock;

   -----------------------------------------------
   --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   --!! Ensure that all outputs are registered. !!
   --!! Check the pinout report to be sure      !!
   --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   -----------------------------------------------
   iob_command <= cmd(command);
   
   sdram_cke  <= iob_cke;
   sdram_cs   <= iob_command(3);
   sdram_ras_n  <= iob_command(2);
   sdram_cas_n  <= iob_command(1);
   sdram_we_n   <= iob_command(0);
   sdram_dqm  <= "00";
   sdram_ba   <= iob_bank;
   sdram_addr <= iob_address;
   
   ---------------------------------------------------------------
   -- Explicitly set up the tristate I/O buffers on the DQ signals
   ---------------------------------------------------------------
iob_dq_g: 
   for i in 0 to 15 generate
      begin
      iob_dq_iob: 
         IOBUF
         generic map (
            DRIVE       => 12, 
            IOSTANDARD  => "LVTTL", 
            SLEW        => "FAST"
         )
         port map (
            IO => sdram_data(i), 
            O  => sdram_din(i), 
            I  => iob_data(i), 
            T  => iob_dq_hiz
         );
   end generate;
                                     
capture_proc: process(clock) 
   begin
     if rising_edge(clock) then
         captured_data <= sdram_din;
      end if;
   end process;

main_proc:
   process(clock) 
   begin
      if rising_edge(clock) then
      
         ------------------------------------------------
         -- Default state is to do nothing
         ------------------------------------------------
         command      <= C_NOP;
         iob_address  <= (others => '0');
         iob_bank     <= (others => '0');

         ------------------------------------------------
         -- Countdown for initialisation & refresh
         ------------------------------------------------
         startup_refresh_count <= startup_refresh_count+1;

         ----------------------------------------------------------------------------
         -- Update shift registers used to choose when to present data from memory
         ----------------------------------------------------------------------------
         data_ready_delay  <= '0' & data_ready_delay(data_ready_delay'left downto 1);
         
         -------------------------------------------------------------------
         -- If we are ready for a new tranasction and one is being presented
         -- then accept it. Also remember what we are reading or writing,
         -- and if it can be back-to-backed with the last transaction
         -------------------------------------------------------------------
         if (ready_for_new = '1') and (cmd_enable = '1') then
            if (save_bank = addr_bank) and (save_row = addr_row) then
               can_back_to_back <= '1';
            else
               can_back_to_back <= '0';
            end if;
            save_row         <= addr_row;
            save_bank        <= addr_bank;
            save_col         <= addr_col;
            save_wr          <= cmd_wr; 
            save_data_in     <= cmd_data_in;
            got_transaction  <= '1';
            ready_for_new    <= '0';
         end if;

         ------------------------------------------------
         -- Handle the data coming back from the 
         -- SDRAM for the Read transaction
         ------------------------------------------------
         data_out_ready <= '0';
         if (data_ready_delay(0) = '1') then
            data_out       <= captured_data;
            data_out_ready <= '1';
         end if;
         
         case state is 
            when s_startup =>
               ------------------------------------------------------------------------
               -- This is the initial startup state, where we wait for at least 100us
               -- before starting the start sequence
               -- 
               -- The initialisation is sequence is 
               --  * de-assert sdram_cke
               --  * 100us wait, 
               --  * assert sdram_cke
               --  * wait at least one cycle, 
               --  * PRECHARGE
               --  * wait 2 cycles
               --  * REFRESH, 
               --  * tREF wait
               --  * REFRESH, 
               --  * tREF wait 
               --  * LOAD_MODE_REG 
               --  * 2 cycles wait
               ------------------------------------------------------------------------
               iob_CKE <= '1';
               
               -- All the commands during the startup are NOPS, except these
               if (startup_refresh_count) = (startup_refresh_max-31) then      
                  -- Ensure all rows are closed
                  command      <= C_PRECHARGE;
                  iob_address  <= PRECHARGE_ON;  -- all banks
                  iob_bank     <= (others => '0');
               elsif (startup_refresh_count = startup_refresh_max-23) then   
                  -- These refreshes need to be at least tREF (66ns) apart
                  command      <= C_REFRESH;
               elsif (startup_refresh_count = startup_refresh_max-15) then
                  command      <= C_REFRESH;
               elsif (startup_refresh_count = startup_refresh_max-7) then    
                  -- Now load the mode register
                  command      <= C_LOAD_MODE_REG;
                  iob_address  <= MODE_REG;
               end if;

               ------------------------------------------------------
               -- if startup is complete then go into idle mode,
               -- get prepared to accept a new command, and schedule
               -- the first refresh cycle
               ------------------------------------------------------
               if (startup_refresh_count = 0) then
                  state                 <= s_idle;
                  ready_for_new         <= '1';
                  got_transaction       <= '0';
                  startup_refresh_count <= to_unsigned(2048 - cycles_per_refresh+1,14);
               end if;
               
            when s_idle_in_6 => 
               state <= s_idle_in_5;
            
            when s_idle_in_5 => 
               state <= s_idle_in_4;
            
            when s_idle_in_4 => 
               state <= s_idle_in_3;
            
            when s_idle_in_3 => 
               state <= s_idle_in_2;
            
            when s_idle_in_2 => 
               state <= s_idle_in_1;
            
            when s_idle_in_1 => 
               state <= s_idle;

            when s_idle =>
               -- Priority is to issue a refresh if one is outstanding
               if (pending_refresh = '1') or (forcing_refresh = '1') then
                 ------------------------------------------------------------------------
                  -- Start the refresh cycle. 
                  -- This tasks tRFC (66ns), so 6 idle cycles are needed @ 100MHz
                  ------------------------------------------------------------------------
                  state                 <= s_idle_in_6;
                  command               <= C_REFRESH;
                  startup_refresh_count <= startup_refresh_count - cycles_per_refresh+1;
               elsif (got_transaction = '1') then
                  --------------------------------
                  -- Start the read or write cycle. 
                  -- First task is to open the row
                  --------------------------------
                  state            <= s_open_in_2;
                  command          <= C_ACTIVE;
                  iob_row_address  <= save_row; 
                  iob_bank         <= save_bank;
               end if;               
               
            --------------------------------------------
            -- Opening the row ready for reads or writes
            --------------------------------------------
            when s_open_in_2 => 
               state <= s_open_in_1;

            when s_open_in_1 =>
               -- Still waiting for row to open
               if (save_wr = '1') then
                  state       <=s_write;
                  command     <= C_WRITE;
                  iob_dq_hiz  <= '0';
                  iob_data    <= save_data_in(15 downto 0); -- get the DQ bus out of HiZ early
                  iob_bank         <= save_bank;
                  iob_col_address  <= save_col; 
               else
                  iob_dq_hiz  <= '1';
                  state       <= s_read;
               end if;
               -- we will be ready for a new transaction next cycle!
               ready_for_new   <= '1'; 
               got_transaction <= '0';                  

            ----------------------------------
            -- Processing the read transaction
            ----------------------------------
            when s_read =>
               state            <=s_read_exit;
               command          <= C_READ;
               iob_bank         <= save_bank;
               iob_col_address  <= save_col; 
               
               -- Schedule reading the data values off the bus
               data_ready_delay(data_ready_delay'left) <= '1';
               
               -- Set the data masks to read all bytes
               ready_for_new   <= '1'; -- we will be ready for a new transaction next cycle!
               got_transaction <= '0';
               if ((forcing_refresh = '0') and (got_transaction = '1') and
                    (can_back_to_back = '1') and (save_wr = '0')) then
                  state       <=s_read;
               end if;
            
            when s_read_exit => 
               state     <=s_precharge;
               -- Can we do back-to-back read?
               if (forcing_refresh = '0') and (got_transaction = '1') and 
                  (can_back_to_back = '1') then
                  if (save_wr = '0') then
                     state           <= s_read;
                     ready_for_new   <= '1'; -- we will be ready for a new transaction next cycle!
                     got_transaction <= '0';
                  else
                     state     <=s_open_in_2; -- we have to wait for the read data to come back before we switch the bus into HiZ
                  end if;
               end if;

            ------------------------------------------------------------------
            -- Processing the write transaction
            -------------------------------------------------------------------

            when s_write =>
               state              <= s_write;
               command            <= C_NOP;
               iob_col_address    <= save_col; 
               iob_bank           <= save_bank;
               iob_data           <= save_data_in;
               if (forcing_refresh = '0') and (got_transaction = '1') and 
                  (can_back_to_back = '1') and (save_wr = '1') then
                  -- Back-to-back write?
                  state           <= s_write;
                  command         <= C_NOP;
                  ready_for_new   <= '1';
               end if;
                        
            when s_write_exit =>  -- must wait tRDL, hence the extra idle state
               -- Back to back transaction?
               if (forcing_refresh = '0') and (got_transaction = '1') and (can_back_to_back = '1') then
                  if (save_wr = '1') then
                     -- Back-to-back write?
                     state           <= s_write_exit;
                     ready_for_new   <= '1';
                     got_transaction <= '0';
                  else
                     -- Write-to-read switch?
                     state           <= s_write;
                     iob_dq_hiz      <= '1';
                     ready_for_new   <= '1'; -- we will be ready for a new transaction next cycle!
                     got_transaction <= '0';                  
                  end if;
               else
                  iob_dq_hiz         <= '1';
                  state              <= s_precharge;
               end if;

            -------------------------------------------------------------------
            -- Closing the row off (this closes all banks)
            -------------------------------------------------------------------
            when s_precharge =>
               state           <= s_idle_in_3;
               command         <= C_PRECHARGE;
               iob_address     <= PRECHARGE_ON; -- No auto precharge

            -------------------------------------------------------------------
            -- We should never get here, but if we do then reset the memory
            -------------------------------------------------------------------
            when others => 
               state                 <= s_startup;
               ready_for_new         <= '0';
               startup_refresh_count <= startup_refresh_max-to_unsigned(startup_cycles,14);
         end case;

         if (reset = '1') then  -- Sync reset
            state                 <= s_startup;
            ready_for_new         <= '0';
            startup_refresh_count <= startup_refresh_max-to_unsigned(startup_cycles,14);
         end if;
      end if;      
   end process;
end Behavioral;