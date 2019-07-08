-- $Header: /devl/xcs/repo/env/Databases/CAEInterfaces/vhdsclibs/data/unisims/rainier/VITAL/CFGLUT5.vhd,v 1.1 2008/06/19 16:59:21 vandanad Exp $
-------------------------------------------------------------------------------
-- Copyright (c) 1995/2004 Xilinx, Inc.
-- All Right Reserved.
-------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor : Xilinx
-- \   \   \/     Version : 11.1
--  \   \         Description : Xilinx Functional Simulation Library Component
--  /   /                 5-input Dynamically Reconfigurable Look-Up-Table with Carry and Clock Enable 
-- /___/   /\     Filename : CFGLUT5.vhd
-- \   \  /  \    Timestamp : 
--  \___\/\___\
--
-- Revision:
--    12/28/05 - Initial version.
--    04/13/06 - Add address declaration. (CR229735)
-- End Revision

----- CELL CFGLUT5 -----
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cfglut5 is

  generic (
    init : bit_vector := x"00000000"
  );

  port (
        cdo : out std_ulogic;
        o5  : out std_ulogic;
        o6  : out std_ulogic;

        cdi : in std_ulogic;
        ce  : in std_ulogic;
        clk : in std_ulogic;        
        i0  : in std_ulogic;
        i1  : in std_ulogic;
        i2  : in std_ulogic;
        i3  : in std_ulogic;
        i4  : in std_ulogic
       ); 
end cfglut5;

architecture cfglut5_v of cfglut5 is
  signal shift_reg   : std_logic_vector (31 downto 0) :=  to_stdlogicvector(init);
  signal o6_slv      : std_logic_vector (4 downto 0) ;
  signal o5_slv      : std_logic_vector (3 downto 0) ;
  signal o6_addr     : integer := 0;
  signal o5_addr     : integer := 0;
begin

    o6_slv  <= i4 & i3 & i2 & i1 & i0;
    o5_slv  <= i3 & i2 & i1 & i0;
    o6_addr <= to_integer(unsigned(o6_slv(4 downto 0)));
    o5_addr <= to_integer(unsigned(o5_slv(3 downto 0)));
    o6      <= shift_reg(o6_addr);
    o5      <= shift_reg(o5_addr);
    cdo     <= shift_reg(31);

  writebehavior : process
    variable first_time : boolean := true;
  begin

    if (first_time) then
        wait until ((ce = '1' or ce = '0') and
                   (clk'last_value = '0' or clk'last_value = '1') and
                   (clk = '0' or clk = '1'));
        first_time := false;
    end if;

    if rising_edge(clk) then
        if (ce = '1') then
           shift_reg(31 downto 0) <= (shift_reg(30 downto 0) & cdi) after 100 ps;
        end if ;
    end if;

    wait on clk;

  end process writebehavior;

end cfglut5_v;