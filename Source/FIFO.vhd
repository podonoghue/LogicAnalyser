library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.logicanalyserpackage.all;

-- Wavedrom examples
--{signal: [  
--  
--  {name: 'item count', wave: '=.=..===.', data:["0","1","2","1","0"]},
--  {name: 'clock',      wave: 'P........'},
--  {name: 'dataIn',     wave: 'x3x45x...', data:["d0","d1","d2","d3"]},
--  {name: 'tail',       wave: '=.=.==...', data:["0","1","2","3"]},
--  {name: 'fifo_wr_en',      wave: '0101.0...'},
--  {name: 'fifo_empty',      wave: '1.0....1.'},
--  {name: 'head',       wave: '=...=.==.', data:["0","1","2","3"]},
--  {name: 'fifo_rd_en',      wave: '0..101.0.'},
--  {name: 'dataOut',    wave: 'xx3.4.5x.', data:["d0","d1","d2"]},
--  {name: 'fifo_full',       wave: '0........'}],  
--   head:{
--   text:'Example 1 - Near fifo_empty',
--   tick:0,
-- },
--  config: {hscale: 1},
--  }
--
--{signal: [
--  {name: 'item count', wave: '=.=.==...', data:["14","15","16","15"]},
--  {name: 'clock',      wave: 'P........'},
--  {name: 'dataIn',     wave: 'x3x45x...', data:["d0","d1","d2"]},
--  {name: 'tail',       wave: '=.=.==...', data:["8","9","10","11"]},
--  {name: 'fifo_wr_en',      wave: '0101.0...'},
--  {name: 'fifo_empty',      wave: '0........'},
--  {name: 'head',       wave: '=....===.', data:["10","11","12","13"]},
--  {name: 'fifo_rd_en',      wave: '0...1..0.'},
--  {name: 'dataOut',    wave: '5....435.', data:["d7","d8","d9","d10"]},
--  {name: 'fifo_full',       wave: '0...1.0..'}],
--
--   head:{
--   text:'Example 2 - Near fifo_full',
--   tick:0,
-- },
--  config: {hscale: 1},
--  }

entity fifo is
   port ( 
      clock         : in   std_logic;
      reset         : in   std_logic;
      
      fifo_full     : out  std_logic;
      fifo_wr_en    : in   std_logic;
      fifo_data_in  : in   SampleDataType;
      
      fifo_empty    : out  std_logic;
      fifo_rd_en    : in   std_logic;
      fifo_data_out : out  SampleDataType      
   );
end fifo;

architecture behavioral of fifo is
   
   constant RAM_BITS : natural := 14; -- real 10;
   constant RAM_SIZE : natural := 2**RAM_BITS;
   subtype FifoAddressType is unsigned(RAM_BITS-1 downto 0);
   
   type RamType is array (0 to RAM_SIZE-1) of SampleDataType;
   signal ram: RamType := (others => (others => '0'));
   
   signal writeAddress : FifoAddressType := (others => '0');
   signal readAddress  : FifoAddressType := (others => '0');
   
   signal isFull  : std_logic;
   signal isEmpty : std_logic;
   
begin

   fifo_empty <= isEmpty;
   fifo_full  <= isFull;
   
   RamProc:
   process (clock)

   begin
      if rising_edge(clock) then
         if ((fifo_wr_en = '1') and (isFull = '0')) then
            if (writeAddress = readAddress-1) and (fifo_rd_en = '0') then
               isFull <= '1';
            end if;
            isEmpty <= '0';
            ram(to_integer(writeAddress)) <= fifo_data_in;
            writeAddress <= writeAddress + 1;
         end if;
         if ((fifo_rd_en = '1') and (isEmpty = '0')) then
            if (readAddress = writeAddress-1) and (fifo_wr_en = '0') then
               isEmpty <= '1';
            end if;
            readAddress <= readAddress + 1;
            isFull      <= '0';
         end if;
         if (reset = '1') then
            writeAddress <= (others => '0');
            readAddress  <= (others => '0');
            isEmpty      <= '1';
            isFull       <= '0';
         end if;
      end if;
   end process;
   
   fifo_data_out <= ram(to_integer(readAddress));
						
end behavioral;

