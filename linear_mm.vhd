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

entity linear_mm is
generic (
    NOTECOUNT : integer := 128;
    PROCESS_BW : integer := 18;
    linear_BW  : integer := 10;
    CTRL_COUNT : integer := 4
);
port (
    clk               : in STD_LOGIC;
    rst               : in STD_LOGIC;
    
    Z02_ctrl_in          : in sfixed;
    Z00_addr             : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
    env_3EndPoints_wr     : in std_logic; 
    env_3EndPoints_wraddr : in std_logic_vector(integer(round(log2(real(NOTECOUNT)))) - 1 downto 0);
    env_3EndPoints_wrdata : in std_logic_vector(linear_BW*2 - 1 downto 0);

    Z05_Bez_Out : out sfixed(1 downto -PROCESS_BW + 2);
    run         : in std_logic_vector
    );
end linear_mm;

architecture Behavioral of linear_mm is
Constant ADDR_WIDTH : integer := integer(round(log2(real(NOTECOUNT))));
type allctrlscaletype   is array (0 to CTRL_COUNT-1) of std_logic_vector(PROCESS_BW - 1 downto 0);
type allctrlscaletypesf is array (0 to CTRL_COUNT-1) of sfixed(1 downto -PROCESS_BW +2);
signal Z01_Ctrl_scale      : allctrlscaletype;
signal Z02_Ctrl_scaleSf    : allctrlscaletypesf;

signal Z01_3EndPoints     : std_logic_vector(linear_BW*2 - 1 downto 0);
signal Z02_STARTpoint_sf  : sfixed(1 downto -linear_BW + 2) := (others=>'0');
signal Z02_ENDpoint_sf  : sfixed(1 downto -linear_BW + 2) := (others=>'0');

begin

linearPair : entity work.simple_dual_one_clock
generic map(
    DATA_WIDTH   => linear_BW*2, 
    ADDR_WIDTH   => ADDR_WIDTH
    )
port map(
    clk   => clk  ,
    wren   => env_3EndPoints_wr,
    rden   => run(Z00)    ,
    wea   => '1'         ,
    wraddr => env_3EndPoints_wraddr,
    rdaddr => Z00_addr,
    wrdata   => env_3EndPoints_wrdata,
    rddata   => Z01_3EndPoints 
);
    

process (clk)
begin
  if rising_edge(clk) then 
    if rst = '0' then
        if run(Z01) = '1' then
            loop3:
            for i in 0 to 1 loop
                Z02_STARTpoint_sf <= sfixed(Z01_3EndPoints(2*linear_BW-1 downto 1*linear_BW));
                Z02_ENDpoint_sf   <= sfixed(Z01_3EndPoints(1*linear_BW-1 downto 0*linear_BW));
            end loop;
        end if;
    end if;
  end if;
end process;

-- the result of the scaling goes into a linear curve
linearStage0 : entity work.linear
Port map(
    clk            => clk ,
    rst            => rst ,
    
    Z00_X          => Z02_ctrl_in ,
    
    Z00_STARTPOINT => Z02_STARTpoint_sf,
    Z00_ENDPOINT   => Z02_ENDpoint_sf,
    
    -- the output of which is a  on range [0, 1)
    Z03_Y          => Z05_Bez_Out,
    
    run            => run
);

end behavioral;