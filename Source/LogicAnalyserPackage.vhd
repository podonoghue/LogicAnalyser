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
constant NUM_LUT_BITS : positive := 32;

-- Data type used for sample data paths
subtype LutConfigType is std_logic_vector(NUM_LUT_BITS-1 downto 0);

--==========================================================
-- Data bus

-- Width of read/write data bus
constant BUS_WIDTH  : positive := 16;

-- Data type used for read/write data bus
subtype DataBusType is std_logic_vector(BUS_WIDTH-1 downto 0);

--==========================================================
-- Sample inputs

-- Number of sample inputs
constant SAMPLE_WIDTH : positive := 2;

-- Data type used for sample data paths
subtype SampleDataType is std_logic_vector(SAMPLE_WIDTH-1 downto 0);

--==========================================================
-- Triggering

-- Maximum number of steps in complex trigger sequence
constant MAX_TRIGGER_STEPS  : positive := 4;

-- Type for a trigger iteration
subtype TriggerRangeType is integer range 0 to MAX_TRIGGER_STEPS-1;

-- Maximum number of conditions for each trigger step (either 2 or 4)
constant MAX_TRIGGER_CONDITIONS  : positive := 2;

-- Number of bits for counter for each trigger step
constant MATCH_COUNTER_BITS  : positive := 16;

-- Type for Trigger match counter
subtype MatchCounterType is unsigned(MATCH_COUNTER_BITS-1 downto 0);
 
-- Type for array of all trigger conditions used 
type TriggerConditionArray is array (MAX_TRIGGER_STEPS-1 downto 0) of std_logic_vector(MAX_TRIGGER_CONDITIONS-1 downto 0);

end LogicAnalyserPackage;