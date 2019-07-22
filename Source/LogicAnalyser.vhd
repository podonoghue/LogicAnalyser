library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.all;
use work.LogicAnalyserPackage.all;

entity LogicAnalyser is
   port ( 
      reset          : in    std_logic;
      clock_100MHz   : in    std_logic;
      clock_100MHz_n : in    std_logic;
      clock_200MHz   : in    std_logic;

      -- FT2232 Interface
      ft2232h_rxf_n  : in    std_logic;   -- Rx FIFO Full
      ft2232h_txe_n  : in    std_logic;   -- Tx FIFO Empty 
      ft2232h_rd_n   : out   std_logic;   -- Rx FIFO Read (Output current data, FIFO advanced on rising edge)
      ft2232h_wr_n     : out   std_logic;   -- Tx FIFO Write (Data captured on rising edge)
      ft2232h_data   : inOut DataBusType; -- FIFO Data I/O
      
      -- Trigger logic
      enable         : in    std_logic;
      sample         : in    SampleDataType;
      triggerFound   : out   std_logic;

      -- SDRAM interface
      sdram_clk      : out   std_logic;
      sdram_cke      : out   std_logic;
      sdram_cs       : out   std_logic;
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

   signal currentSample           : SampleDataType;
   signal lastSample              : SampleDataType;
   
   -- SDRAM interface             
   signal cmd_ready               : std_logic; 
   signal cmd_enable              : std_logic; 
   signal cmd_wr                  : std_logic;  
   signal cmd_done                : std_logic; 

   signal cmd_dataIn              : sdram_phy_DataType;
                                  
   signal cmd_dataOut             : sdram_phy_DataType;
   signal cmd_dataOutReady        : std_logic;
   signal cmd_address             : sdram_AddrType;
      
   signal lastReadData            : DataBusType;
   signal lastReadDataValid       : std_logic;
   
   signal dataOutOred             : DataBusType;
   signal dataOutTriggerBlock     : DataBusType;
   
   -- FT2232H Interface
   signal receive_data            : DataBusType;
   signal receive_data_st         : std_logic;

   signal send_data              : DataBusType;
   signal send_data_req          : std_logic;

   -- Control state machine
   type StateType is (s_cmd, s_size, s_data);
   signal state : StateType;
   
   signal command     : DataBusType;
   
   signal wr_trigger_luts    : std_logic;
   signal receive_data_ready : std_logic;
   signal send_data_ready    : std_logic;
   signal trigger_bus_busy   : std_logic;
   
begin
   
   send_data     <= x"A5";
   
   ft2232h_Interface_inst:
   entity work.ft2232h_Interface 
   PORT MAP (
      reset              => reset,
      clock_100MHz       => clock_100MHz,
      
      -- FT2232H interface
      ft2232h_rxf_n      => ft2232h_rxf_n,
      ft2232h_rd_n       => ft2232h_rd_n,
      
      ft2232h_txe_n      => ft2232h_txe_n,
      ft2232h_wr_n       => ft2232h_wr_n,
      
      ft2232h_data       => ft2232h_data,
      
      -- Analyser interface
      receive_data       => receive_data,
      receive_data_ready => receive_data_ready,
      receive_data_st    => receive_data_st,
      
      send_data          => send_data,
      send_data_req      => send_data_req,
      send_data_ready    => send_data_ready
   );

   send_data_req <= cmd_dataOutReady;

   cmd_enable        <= '0';
   cmd_wr            <= '0';
   cmd_dataIn        <= (others => '1');
   cmd_address       <= (others => '1');
   
   SDRAM_Controller_inst :
   entity work.SDRAM_Controller
   port map(
      clock_100MHz     => clock_100MHz,
      clock_100MHz_n   => clock_100MHz_n,
      reset            => reset,

      cmd_wr           => cmd_wr,
      cmd_enable       => cmd_enable,
      cmd_address      => cmd_address,
      cmd_dataIn       => cmd_dataIn,

      cmd_done         => cmd_done,
      cmd_dataOut      => cmd_dataOut,
      cmd_dataOutReady => cmd_dataOutReady,
      
      intializing      => open,
      
      sdram_clk        => sdram_clk,
      sdram_cke        => sdram_cke,
      sdram_cs         => sdram_cs,
      sdram_ras_n      => sdram_ras_n,
      sdram_cas_n      => sdram_cas_n,
      sdram_we_n       => sdram_we_n,
      sdram_dqm        => sdram_dqm,
      sdram_ba         => sdram_ba,
      sdram_addr       => sdram_addr,
      sdram_data       => sdram_data
   );

   Sampling_proc:
   process(reset, clock_100MHz) 
   begin
      if rising_edge(clock_100MHz) then
         if (reset = '1') then
            currentSample    <= (others => '0');
            lastSample       <= (others => '0');
         else
            currentSample    <= sample;
            lastSample       <= currentSample;
         end if;
      end if;
   end process;

	-- Instantiate the Unit Under Test (UUT)
   TriggerBlock_inst: 
   entity TriggerBlock 
      port map (
         clock          => clock_100MHz,
         reset          => reset,
         enable         => enable,
         currentSample  => currentSample,
         lastSample     => lastSample,
         triggerFound   => triggerFound,
         
         -- Bus interface
         wr_luts        => wr_trigger_luts,       
         dataIn         => receive_data,   
         rd_luts        => '0',
         dataOut        => open,         
         bus_busy       => trigger_bus_busy
        );

   ProcSwitching:
   process(command, receive_data_st, trigger_bus_busy)
   begin
      -- Default to not accept new data
      receive_data_ready  <= '0';
      wr_trigger_luts     <= '0';
      
      case (command) is
         when C_NOP =>
            receive_data_ready  <= '1';
            null;
            
         when C_LUT_CONFIG =>
            receive_data_ready  <= not trigger_bus_busy;
            if (state = s_data) then
              wr_trigger_luts     <= receive_data_st;
            end if;            
         when others =>
            null;
      end case;
      
      -- Always accept data in these states
      if ((state = s_cmd) or (state = s_size)) then
         receive_data_ready  <= '1';
      end if;
   end process;
   
   ProcStateMachine:
   process(clock_100MHz)

      variable data_count : natural range 0 to 255;
      
   begin
      if rising_edge(clock_100MHz) then
         case (state) is
            when s_cmd =>
               if (receive_data_st = '1') then
                  command <= receive_data;
                  if (receive_data /= C_NOP) then
                     state <= s_size;
                  end if;
               end if;                  
            when s_size =>
               if (receive_data_st = '1') then
                  data_count := to_integer(unsigned(receive_data));
                  state <= s_data;
               end if;                  
            when s_data =>
               if (receive_data_st = '1') then
                  data_count := data_count-1;
                  if (data_count = 0) then
                     state   <= s_cmd;
                     command <= C_NOP;
                  end if;
               end if;                  
         end case;
         if (reset = '1') then
            state   <= s_cmd;
            command <=  C_NOP;
         end if;
      end if;
   end process;
end Behavioral;