library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- create a 1D control as a function of
-- patch age, note age, 
-- ??? Need better info

entity bezier_mm is
generic (
    NOTECOUNT : integer := 128;
    PROCESS_BW : integer := 18;
    BEZIER_BW  : integer := 10;
    CTRL_COUNT : integer := 4
);
port (
    clk               : in STD_LOGIC;
    rst               : in STD_LOGIC;
    
    Z00_ctrl_in    : in sfixed(1 downto -PROCESS_BW + 2);
    Z00_addr       : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);

    env_bezier_BEGnMIDnENDpoint_wr     : in std_logic; 
    env_bezier_BEGnMIDnENDpoint_wraddr : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
    env_bezier_BEGnMIDnENDpoint_wrdata : in std_logic_vector(BEZIER_BW*3 - 1 downto 0);

    Z05_Bez_Out : out sfixed(1 downto -PROCESS_BW + 2);
    run         : in std_logic_vector
    );
end bezier_mm;

architecture arch_imp of bezier_mm is
Constant ADDR_WIDTH : integer := integer(round(log2(real(NOTECOUNT))));

type BezierTriple      is array(0 to 2) of sfixed(1 downto -BEZIER_BW + 2);
signal Z01_Bezier_Triple     : std_logic_vector(BEZIER_BW*3 - 1 downto 0);
signal Z02_Bezier_Triple_sf  : BezierTriple;

begin

BezierTripleX3 : entity work.simple_dual_one_clock
generic map(
    DATA_WIDTH   => BEZIER_BW*3, 
    ADDR_WIDTH   => ADDR_WIDTH
    )
port map(
    clk   => clk  ,
    wren   => env_bezier_BEGnMIDnENDpoint_wr,
    rden   => run(Z00)    ,
    wea   => '1'         ,
    wraddr => env_bezier_BEGnMIDnENDpoint_wraddr,
    rdaddr => Z00_addr,
    wrdata   => env_bezier_BEGnMIDnENDpoint_wrdata,
    rddata   => Z01_Bezier_Triple 
);
    

process (clk)
begin
  if rising_edge(clk) then 
    if rst = '0' then
        if run(Z01) = '1' then
            loop3:
            for i in 0 to 2 loop
                Z02_Bezier_Triple_sf(i) <= sfixed(Z01_Bezier_Triple((i+1)*BEZIER_BW-1 downto i*BEZIER_BW));
            end loop;
        end if;
    end if;
  end if;
end process;

bezierStage0 : entity work.bezier
Port map(
    clk            => clk ,
    rst            => rst ,
    
    Z00_X          => Z00_ctrl_in ,
    
    Z02_STARTPOINT => Z02_Bezier_Triple_sf(2),
    Z02_MIDPOINT   => Z02_Bezier_Triple_sf(1),
    Z02_ENDPOINT   => Z02_Bezier_Triple_sf(0),
    
    -- the output of which is a  on range [0, 1)
    Z05_Y          => Z05_Bez_Out,
    
    run            => run
);

end arch_imp;