----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Create Date:    14:09:12 09/15/2013 
-- Module Name:    SDRAM_Controller - Behavioral 
-- Description:    Simple SDRAM controller for a Micron 48LC16M16A2-7E
--                 or Micron 48LC4M16A2-7E @ 100MHz      
-- Revision: 
-- Revision 0.1 - Initial version
-- Revision 0.2 - Removed second clock_100MHz signal that isn't needed.
-- Revision 0.3 - Added back-to-back reads and writes.
-- Revision 0.4 - Allow refeshes to be delayed till next PRECHARGE is issued,
--                Unless they get really, really delayed. If a delay occurs multiple
--                refreshes might get pushed out, but it will have avioded about 
--                50% of the refresh overhead
-- Revision 0.5 - Add more paramaters to the design, allowing it to work for both the 
--                Papilio Pro and Logi-Pi
-- Revision 0.6 - Fixed bugs in back-to-back reads (thanks Scotty!)
-- Heavily modified for analyser - pgo
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
      clock_100MHz      : in    std_logic;
      clock_100MHz_n    : in    std_logic;
      reset             : in    std_logic;

      -- Interface to issue reads or write data
      cmd_wr            : in    std_logic;          
      cmd_rd            : in    std_logic;          
      cmd_address       : in    sdram_AddrType;     
      cmd_wr_accepted   : out   std_logic;          
      cmd_rd_accepted   : out   std_logic;          
      cmd_done          : out   std_logic;          

      cmd_dataIn        : in    sdram_DataType;
      
      cmd_dataOut       : out   sdram_phy_DataType;
      cmd_dataOutReady  : out   std_logic;         
      
      intializing       : out   std_logic;

      -- SDRAM signals 
      sdram_clk         : out   std_logic;
      sdram_cke         : out   std_logic;
      sdram_cs_n        : out   std_logic;
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

   signal sdram_dataOut     : sdram_phy_DataType;
   signal sdram_dataIn      : sdram_phy_DataType;
   
   ------------------------------------------------------------------
   -- !! Ensure that outputs and inputs are registered in the IOB. !!
   -- !! Check the pinout report to be sure                        !!
   -- !! RAS, CAS, WE, DQM, ADDR, BA = OFF                         !!
   -- !! DATA                        = IFF OFF                     !!
   -- !! CLK                         = ODDR                        !!
   -- !! CS and CKE are static and will not be FFs                 !!
   ------------------------------------------------------------------
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
   constant MODE_REG        : sdram_phy_AddrType := CAS_2 or BURST_NONE;
   
   type StateType is (s_startup,
                      s_refresh, 
                      s_idle_in_5, s_idle_in_4, s_idle_in_3, s_idle_in_2, s_idle_in_1,
                      s_idle,
                      s_active, s_pre_read,
                      s_pre_write,  s_write,  s_write_exit,
                      s_read,   s_read_exit,  
                      s_precharge
                      );

   signal state           : StateType;
   attribute FSM_ENCODING : string;
   attribute FSM_ENCODING of state : signal is "ONE-HOT";
   
   -- Dual purpose counter, it counts up during the startup phase, then is used to trigger refreshes.
   constant startup_refresh_max   : unsigned(13 downto 0) := (others => '1');  
   constant startup_reset_value   : unsigned(13 downto 0) := startup_refresh_max-to_unsigned(startup_cycles,14);
   signal   startup_refresh_count : unsigned(13 downto 0) := startup_reset_value;

   -- Indicate the need to refresh when the counter is 2048,
   -- Force a refresh when the counter is 4096 - (if a refresh is forced, 
   -- multiple refreshes will be forced until the counter is below 2048)
   alias pending_refresh          : std_logic is startup_refresh_count(11);
   alias forcing_refresh          : std_logic is startup_refresh_count(12);

   --  2  2  2  2  1  1  1  1  1  1  1  1  1  
   --  3  2  1  0  9  8  7  6  5  4  3  2  1  0  9  8  7  6  5  4  3  2  1  0  
   -- +------------------------------------+-----+--------------------------+
   -- |            Row Address             | Bank|      Column Address      | Logical Address
   -- +------------------------------------+-----+--------------------------+
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
--   constant PRECHARGE_ON   : sdram_phy_AddrType := (10 => '1', others => '0');
   
   -- Bit indexes used when splitting the address into row/colum/bank.
   constant start_of_col       : natural :=  0;
   constant start_of_bank      : natural :=  9;
   constant start_of_row       : natural := 11;
   
   -- The incoming address is split into these three values
   alias  addr_col             : std_logic_vector(8 downto 0)  is cmd_address(start_of_bank-1  downto start_of_col);
   alias  addr_bank            : sdram_phy_BankSelType         is cmd_address(start_of_row-1   downto start_of_bank);
   alias  addr_row             : std_logic_vector(12 downto 0) is cmd_address(cmd_address'left downto start_of_row);
   
   alias  sdram_col_address    : std_logic_vector is sdram_addr(addr_col'range);
   alias  sdram_row_address    : std_logic_vector is sdram_addr(addr_row'range);
   alias  sdram_precharge      : std_logic        is sdram_addr(10);
   signal transaction_request  : std_logic;
    
   -- Signals to hold the last transaction to allow detection of bank and row changes
   signal last_row             : std_logic_vector(addr_row'range);
   signal last_bank            : std_logic_vector(addr_bank'range);
   signal last_data_in         : std_logic_vector(cmd_dataIn'range);

   -- Control when new transactions are accepted
   signal ready_for_new        : std_logic;
   signal back_to_back_request : std_logic;

   -- signal to control the Hi-Z state of the DQ bus
   signal sdram_dq_hiz         : std_logic;

   -- Shift-register to indicate when to read the value from of the SDRAM data bus
   constant READ_LATENCY       : natural := 2;   
   signal data_ready_delay     : std_logic_vector(READ_LATENCY-1 downto 0);   
   
   signal write_data_captured  : std_logic;
   
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
      R  => '0', 
      S  => '0', 
      CE => '1', 
      D0 => '0', 
      D1 => '1',
      C0 => clock_100MHz, 
      C1 => clock_100MHz_n, 
      Q  => sdram_clk 
   );

   sdram_cs_n   <= cmd(command)(3);
   sdram_ras_n  <= cmd(command)(2);
   sdram_cas_n  <= cmd(command)(1);
   sdram_we_n   <= cmd(command)(0);
   
   sdram_data <= sdram_dataOut when sdram_dq_hiz = '0' else (others => 'Z');

   transaction_request  <= cmd_wr or cmd_rd;
   back_to_back_request <= '1' when ((transaction_request = '1') and (last_bank = addr_bank) and (last_row = addr_row)) else '0';
   cmd_done             <= ready_for_new and back_to_back_request;

main_proc:
   process(clock_100MHz) 
      
   begin
      if rising_edge(clock_100MHz) then
      
         ------------------------------------------------
         -- Default is to do nothing
         ------------------------------------------------
         command           <= C_NOP;
         sdram_addr        <= (others => '0');
         sdram_ba          <= (others => '0');
         sdram_dqm         <= (others => '1');
         ready_for_new     <= '0';
         sdram_dq_hiz      <= '1';
         intializing       <= '0';
         cmd_rd_accepted   <= '0';
         cmd_wr_accepted   <= '0';

         ------------------------------------------------
         -- Countdown for initialisation & refresh
         ------------------------------------------------
         startup_refresh_count <= startup_refresh_count+1;

         ----------------------------------------------------------------------------
         -- Update shift registers used to choose when to present data from memory
         ----------------------------------------------------------------------------
         data_ready_delay  <= '0' & data_ready_delay(data_ready_delay'left downto 1);
         
         ------------------------------------------------
         -- Handle the data coming back from the 
         -- SDRAM for the Read transaction
         ------------------------------------------------
         sdram_dataIn <= sdram_data;
         if (data_ready_delay(0) = '1') then
            cmd_dataOut       <= sdram_dataIn;
            cmd_dataOutReady <= '1';
         else
            cmd_dataOutReady <= '0';
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
               sdram_cke   <= '1';
               intializing <= '1';   
               
               -- All the commands during the startup are NOPS, except these
               if (startup_refresh_count) = (startup_refresh_max-31) then      
                  -- Ensure all rows are closed
                  command         <= C_PRECHARGE;
                  sdram_precharge <= '1';  -- all banks
                  sdram_ba        <= (others => '0');
               elsif (startup_refresh_count = startup_refresh_max-23) then   
                  -- These refreshes need to be at least tREF (66ns) apart
                  command         <= C_REFRESH;
               elsif (startup_refresh_count = startup_refresh_max-15) then
                  command         <= C_REFRESH;
               elsif (startup_refresh_count = startup_refresh_max-7) then    
                  -- Now load the mode register
                  command         <= C_LOAD_MODE_REG;
                  sdram_addr      <= MODE_REG;
               end if;

               ------------------------------------------------------
               -- if startup is complete then go into idle mode,
               -- get prepared to accept a new command, and schedule
               -- the first refresh cycle
               ------------------------------------------------------
               if (startup_refresh_count = 0) then
                  state                 <= s_idle;
                  startup_refresh_count <= to_unsigned(2048 - cycles_per_refresh+1,14);
               end if;
               
            when s_refresh => 
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
                  state                 <= s_refresh;
                  command               <= C_REFRESH;
                  startup_refresh_count <= startup_refresh_count - cycles_per_refresh+1;
               elsif (transaction_request = '1') then
                  --------------------------------
                  -- Start the read or write cycle. 
                  -- First task is to open the row
                  --------------------------------
                  state              <= s_active;
                  command            <= C_ACTIVE;
                  sdram_row_address  <= addr_row; 
                  sdram_ba           <= addr_bank;
               end if;               
               
            --------------------------------------------
            -- Opening the row ready for reads or writes
            --------------------------------------------
            when s_active => 
               ready_for_new    <= '1';
               last_row         <= addr_row;
               last_bank        <= addr_bank;
               if (cmd_wr = '1') then
                  state            <= s_pre_write;
                  if (write_data_captured = '0') then
                     cmd_wr_accepted  <= '1';
                  end if;
               else
                  state            <= s_pre_read;
                  cmd_rd_accepted  <= '1';
               end if;

            ----------------------------------
            -- Processing the read transaction
            ----------------------------------

            when s_pre_read =>
               -- Row will be open for read on next clock
               ready_for_new      <= '1';
               state              <= s_read;
               command            <= C_READ;
               sdram_dqm          <= (others => '0');
               sdram_ba           <= addr_bank;
               sdram_col_address  <= addr_col; 

            when s_read =>
               state         <= s_read_exit;
               command       <= C_NOP;

               -- Schedule reading the data values off the bus
               data_ready_delay(data_ready_delay'left) <= '1';
                              
               if ((forcing_refresh = '0') and (back_to_back_request = '1') and (cmd_wr = '0')) then
                  state              <= s_read;
                  command            <= C_READ;
                  sdram_dqm          <= (others => '0');
                  sdram_ba           <= addr_bank;
                  sdram_col_address  <= addr_col; 
                  -- Accept new transactions
                  ready_for_new      <= '1';
               end if;
            
            when s_read_exit => 
               state        <= s_precharge;
               command      <= C_PRECHARGE;
               
               -- Can we do back-to-back read?
               if (forcing_refresh = '0') and (back_to_back_request = '1') then
                  if (cmd_wr = '0') then
                     state              <= s_read;
                     command            <= C_READ;
                     sdram_dqm          <= (others => '0');
                     sdram_ba           <= addr_bank;
                     sdram_col_address  <= addr_col; 
                     -- Accept new transactions
                     ready_for_new      <= '1';
                  else
                     state     <= s_active;
                  end if;
               end if;

            ------------------------------------------------------------------
            -- Processing the write transaction
            -------------------------------------------------------------------
            
            when s_pre_write =>
               -- Row will be open for write on next clock
               ready_for_new       <= '1';
               state               <= s_write;
               command             <= C_WRITE;
               sdram_dqm           <= (others => '0');
               sdram_dq_hiz        <= '0';
               sdram_ba            <= addr_bank;
               --if (write_data_captured = '0') then
                  cmd_wr_accepted     <= '1'; -- write will complete in next cycle             
                  sdram_dataOut       <= cmd_dataIn;
                  sdram_col_address   <= addr_col; 
                  write_data_captured <= '1';
               --end if;               
            
            when s_write =>
               state               <= s_write_exit;
               command             <= C_NOP;
               sdram_dataOut       <= cmd_dataIn;
               sdram_col_address   <= addr_col; 
               write_data_captured <= cmd_wr;

               if (forcing_refresh = '0') and (back_to_back_request = '1') then
                  if (cmd_wr = '1') then
                     -- Back-to-back write?
                     state                <= s_write;
                     command              <= C_WRITE;
                     sdram_dqm            <= (others => '0');
                     sdram_dq_hiz         <= '0';
                     sdram_ba             <= addr_bank;
                     cmd_wr_accepted      <= '1'; -- write will complete in next cycle             
                     -- Accept new transactions
                     ready_for_new        <= '1';
               end if;
            end if;
                        
            when s_write_exit =>  
               -- Must wait tRDL before precharge
               state       <= s_precharge;
               command     <= C_PRECHARGE;

            -------------------------------------------------------------------
            -- Closing the row off (this closes all banks)
            -------------------------------------------------------------------
            when s_precharge =>
               state           <= s_idle;
               command         <= C_NOP;
               
         end case;

         if (reset = '1') then  -- Sync reset
            state                 <= s_startup;
            ready_for_new         <= '0';
            startup_refresh_count <= startup_reset_value;
            write_data_captured   <= '0';
         end if;
      end if;      
   end process;
end Behavioral;