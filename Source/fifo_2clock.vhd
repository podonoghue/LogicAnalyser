library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.all;
use work.logicanalyserpackage.all;

entity fifo_2clock is
    port ( 
      w_clock   : in   std_logic;
      w_clear   : in   std_logic;
      w_enable  : in   std_logic;
      w_isFull  : out  std_logic;
      w_data    : in   sampledatatype;

      r_clock   : in   std_logic;
      r_clear   : in   std_logic;
      r_enable  : in   std_logic;
      r_isEmpty : out  std_logic;
      r_data    : out  sampledatatype
     );
end fifo_2clock;

architecture Behavioral of FIFO_2CLOCK is

   constant RAM_BITS : natural := 10; -- 10; -- debug 5
   constant RAM_SIZE : natural := 2**RAM_BITS;
   subtype FifoAddressType is unsigned(RAM_BITS-1 downto 0);
   
   function binaryToGray(bin : FifoAddressType) return FifoAddressType is
   begin
      return bin xor ('0' & bin(bin'left downto 1));
   end function;

   function grayToBinary(bin : FifoAddressType) return FifoAddressType is
      variable t : FifoAddressType;
   begin
      t(bin'left) := bin(bin'left);
      for index in bin'left-1 downto 0 loop
         t(index) := bin(index) xor t(index+1);
      end loop;
      return t;
   end function;

   type RamType is array (0 to RAM_SIZE-1) of SampleDataType;
   signal ram: RamType;-- := (others => (others => '0'));
   
   signal w_address      : FifoAddressType := (others => '0');
   signal w_address_g_w  : FifoAddressType := (others => '0');
   signal w_address_g_r1 : FifoAddressType := (others => '0');
   signal w_address_g_r2 : FifoAddressType := (others => '0');
   signal w_address_s    : FifoAddressType := (others => '0');

   attribute ASYNC_REG : string;
   attribute ASYNC_REG of w_address_g_r1: signal is "TRUE";
   attribute ASYNC_REG of w_address_g_r2: signal is "TRUE";

   signal r_address      : FifoAddressType := (others => '0');   
   signal r_address_g_r  : FifoAddressType := (others => '0');
   signal r_address_g_w1 : FifoAddressType := (others => '0');
   signal r_address_g_w2 : FifoAddressType := (others => '0');
   signal r_address_s    : FifoAddressType := (others => '0');
   
   attribute ASYNC_REG of r_address_g_w1: signal is "TRUE";
   attribute ASYNC_REG of r_address_g_w2: signal is "TRUE";

   signal isFull  : std_logic;
   signal isEmpty : std_logic;
   
begin
   
   w_isFull  <= isfull;
   r_isEmpty <= isEmpty;
   
writeProc:
process (w_clock)

   variable nextAddr : FifoAddressType;

begin
   if rising_edge(w_clock) then
      -- Convert write address to Gray code and register
      w_address_g_w <= binaryToGray(w_address);

      -- Double synchronize read address from other clock domain
      r_address_g_w1 <= r_address_g_r;
      r_address_g_w2 <= r_address_g_w1;

      -- Convert back to binary
      r_address_s <= grayToBinary(r_address_g_w2);

      if ((w_enable = '1')  and (isfull = '0')) then
         ram(to_integer(w_address)) <= w_data;
         nextAddr := w_address + 1;
         if (nextAddr = r_address_s) then
            isfull <= '1';
         end if;
         w_address <= nextAddr;
      end if;
      if (nextAddr /= r_address_s) then
         isfull <= '0';
      end if;
      if (w_clear = '1') then
         w_address <= (others => '0');
         isfull    <= '0';
      end if;
   end if;
end process;

readProc:
process (r_clock)

   variable nextAddr : FifoAddressType;

begin
   if rising_edge(r_clock) then
      -- Convert read address to Gray code and register
      r_address_g_r <= binaryToGray(r_address);
      
      -- Double synchronize write address from other clock domain
      w_address_g_r1 <= w_address_g_w;
      w_address_g_r2 <= w_address_g_r1;
      
      -- Convert back to binary
      w_address_s <= grayToBinary(w_address_g_r2);
      
      if (r_address /= w_address_s) then
         isempty <= '0';
      end if;
      if ((r_enable = '1') and (isempty = '0')) then
         r_data <= ram(to_integer(r_address));
         nextAddr := r_address + 1;
         if (nextAddr = w_address_s) then
            -- Reading last value in FIFO this clock
            isempty <= '1';
         end if;
         r_address <= nextAddr;
      end if;
      if (r_clear = '1') then
         r_address  <= (others => '0');
         isempty    <= '1';
      end if;
   end if;
end process;

end behavioral;
