--
--	Package defining shared values
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

package LogicAnalyserPackage is

   --==========================================================
   -- LUTs

   -- Number of configuration bits in a LUT
   constant NUM_BITS_PER_LUT : positive := 32;

   -- Data type used for sample data paths
   subtype LutConfigType is std_logic_vector(NUM_BITS_PER_LUT-1 downto 0);

   --==========================================================
   -- Data bus

   -- Width of read/write data bus
   constant DATA_BUS_WIDTH  : positive := 8;

   -- Data type used for read/write data bus
   subtype DataBusType is std_logic_vector(DATA_BUS_WIDTH-1 downto 0);

   --==========================================================
   -- Address bus

   -- Width of read/write data bus
   constant ADDRESS_BUS_WIDTH  : positive := 3;

   -- Data type used for read/write data bus
   subtype AddressBusType is unsigned(ADDRESS_BUS_WIDTH-1 downto 0);

   constant CONTROL_ADDRESS : integer := 0;
   constant LUT_SR_ADDRESS  : integer := 1;

   --==========================================================
   -- Flags used by trigger state machine

   constant NUM_TRIGGER_FLAGS                : integer := 2;
   constant CONTIGUOUS_TRIGGER_INDEX         : integer := 0;
   constant TRIGGER_SEQUENCE_COMPLETE_INDEX  : integer := 1;

   --==========================================================
   -- Sample inputs

   -- Number of sample inputs
   constant SAMPLE_WIDTH : positive := 16; -- Testing 2

   -- Data type used for sample data paths
   subtype SampleDataType is std_logic_vector(SAMPLE_WIDTH-1 downto 0);

   --==========================================================
   -- Triggering

   -- Maximum number of steps in complex trigger sequence
   constant MAX_TRIGGER_STEPS  : positive := 4; -- Actual 16; -- Testing 4

   -- Type for a trigger iteration
   subtype TriggerRangeType    is unsigned(3 downto 0);
   subtype TriggerRangeIntType is natural range 0 to MAX_TRIGGER_STEPS-1;

   -- Maximum number of conditions for each trigger step (either 2 or 4)
   constant MAX_TRIGGER_PATTERNS  : positive := 2;

   -- Number of bits for counter for each trigger step
   constant NUM_MATCH_COUNTER_BITS  : positive := 16;

   -- Type for Trigger match counter
   subtype MatchCounterType is unsigned(NUM_MATCH_COUNTER_BITS-1 downto 0);

   -- Type for array of all trigger conditions used
   type TriggerConditionArray is array (MAX_TRIGGER_STEPS-1 downto 0) of std_logic_vector(MAX_TRIGGER_PATTERNS-1 downto 0);

   --==========================================================
   -- SDRAM configuration
   constant SDRAM_PHY_ADDR_WIDTH  : natural := 13;
   constant SDRAM_PHY_DATA_WIDTH  : natural := 16;
   constant SDRAM_PHY_BYTE_LANES  : natural := SDRAM_PHY_DATA_WIDTH/8;
   constant SDRAM_PHY_BANKS_WIDTH : natural := 2;

   subtype  sdram_phy_AddrType     is std_logic_vector(SDRAM_PHY_ADDR_WIDTH-1 downto 0);
   subtype  sdram_phy_DataType     is std_logic_vector(SDRAM_PHY_DATA_WIDTH-1 downto 0);
   subtype  sdram_phy_ByteSelType  is std_logic_vector(SDRAM_PHY_BYTE_LANES-1 downto 0);
   subtype  sdram_phy_BankSelType  is std_logic_vector(SDRAM_PHY_BANKS_WIDTH-1 downto 0);

   constant SDRAM_ADDR_WIDTH  : natural := 24;
   constant SDRAM_DATA_WIDTH  : natural := 16;
   constant SDRAM_BYTE_LANES  : natural := SDRAM_DATA_WIDTH/8;

   subtype  sdram_AddrType      is std_logic_vector(SDRAM_ADDR_WIDTH-1 downto 0);
   subtype  sdram_DataType      is std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
   subtype  sdram_ByteSelType   is std_logic_vector(SDRAM_BYTE_LANES-1 downto 0);

   --==============================================================
   --
   constant C_RECEIVE_MODE  : DataBusType := "00000000";
   constant C_TRANSMIT_MODE : DataBusType := "10000000";
   constant C_TX_BITNUM     : natural := 7;

   constant C_NOP           : DataBusType := "00000000" or C_RECEIVE_MODE;
   constant C_LUT_CONFIG    : DataBusType := "00000001" or C_RECEIVE_MODE;
   constant C_WR_CONTROL    : DataBusType := "00000010" or C_RECEIVE_MODE;

   constant C_RD_BUFFER     : DataBusType := "00000001" or C_TRANSMIT_MODE;

   type AnalyserCmdType is (ACmd_NOP, ACmd_LUT_CONFIG, ACmd_WR_CONTROL, ACmd_RD_BUFFER);

   --==============================================================
   --
   constant C_CONTROL_ENABLE        : DataBusType := "00000001";
   constant C_CONTROL_CLEAR         : DataBusType := "00000010";
   constant C_CONTROL_CLEAR_COUNTS  : DataBusType := "00000100";
   
   constant C_CONTROL_DIV1          : DataBusType := "00000000";
   constant C_CONTROL_DIV2          : DataBusType := "00001000";
   constant C_CONTROL_DIV5          : DataBusType := "00010000";
   constant C_CONTROL_DIV10         : DataBusType := "00011000";
   
   constant C_CONTROL_DIVx1         : DataBusType := "00000000";
   constant C_CONTROL_DIVx10        : DataBusType := "00100000";
   constant C_CONTROL_DIVx100       : DataBusType := "01000000";
   constant C_CONTROL_DIVx1000      : DataBusType := "01100000";

   constant C_CONTROL_S_10ns  : DataBusType := C_CONTROL_DIVx1    or C_CONTROL_DIV1;
   constant C_CONTROL_S_20ns  : DataBusType := C_CONTROL_DIVx1    or C_CONTROL_DIV2;
   constant C_CONTROL_S_50ns  : DataBusType := C_CONTROL_DIVx1    or C_CONTROL_DIV5;
   constant C_CONTROL_S_100ns : DataBusType := C_CONTROL_DIVx10   or C_CONTROL_DIV1;
   constant C_CONTROL_S_200ns : DataBusType := C_CONTROL_DIVx10   or C_CONTROL_DIV2;
   constant C_CONTROL_S_500ns : DataBusType := C_CONTROL_DIVx10   or C_CONTROL_DIV5;
   constant C_CONTROL_S_1us   : DataBusType := C_CONTROL_DIVx100  or C_CONTROL_DIV1;
   constant C_CONTROL_S_2us   : DataBusType := C_CONTROL_DIVx100  or C_CONTROL_DIV2;
   constant C_CONTROL_S_5us   : DataBusType := C_CONTROL_DIVx100  or C_CONTROL_DIV5;
   constant C_CONTROL_S_10us  : DataBusType := C_CONTROL_DIVx1000 or C_CONTROL_DIV1;
   constant C_CONTROL_S_20us  : DataBusType := C_CONTROL_DIVx1000 or C_CONTROL_DIV2;
   constant C_CONTROL_S_50us  : DataBusType := C_CONTROL_DIVx1000 or C_CONTROL_DIV5;
   constant C_CONTROL_S_100us : DataBusType := C_CONTROL_DIVx1000 or C_CONTROL_DIV10;
   
   -------------------------------------------------------------
   -- Maps readable command names (for debug) to physical values
   --
   function analyserCmd(command : DataBusType) return AnalyserCmdType;

end LogicAnalyserPackage;

package body LogicAnalyserPackage is

  -------------------------------------------------------------
   -- Maps readable command names (for debug) to physical values
   --
   function analyserCmd(command : DataBusType) return AnalyserCmdType is
   begin
      case (command) is
         when C_NOP        => return ACmd_NOP;
         when C_LUT_CONFIG => return ACmd_LUT_CONFIG;
         when C_WR_CONTROL => return ACmd_WR_CONTROL;
         when C_RD_BUFFER  => return ACmd_RD_BUFFER;
         when others       => return ACmd_NOP;
      end case;
   end function;

end package body LogicAnalyserPackage;