----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

Library work;
use work.spectral_pkg.all;

-- takes startpoint, midpoint, endpoint, and x-value (-1, 1)
-- exports the quadratic bezier_tb at that point

entity bezier_tb is
end bezier_tb;

architecture Behavioral of bezier_tb is
constant IN_BW : integer := 18;
constant OUT_BW: integer := 18;

signal clk           : STD_LOGIC := '0';
signal rst           : STD_LOGIC := '0';
signal Z00_X         : sfixed(1 downto -IN_BW + 2) := to_sfixed(-1.0, 1, -IN_BW + 2);
signal Z02_STARTPOINT: sfixed(1 downto -IN_BW + 2) := (others=>'0');
signal Z02_ENDPOINT  : sfixed(1 downto -IN_BW + 2) := to_sfixed(1.0, 1, -IN_BW + 2);
signal Z02_MIDPOINT  : sfixed(2 downto -IN_BW + 3) := to_sfixed(0.1, 2, -IN_BW + 3);
signal Z05_Y         : sfixed(1 downto -OUT_BW + 2) := (others=>'0');
signal run           : std_logic_vector(4 downto 0);

begin

clk <= not clk after 10ns;

-- consolidate the results of the three curves into a new bezier
dut : entity work.bezier
Port map(
    clk            => clk           ,
    rst            => rst           ,
    
    Z00_X          => Z00_X         ,
                                    
    Z02_STARTPOINT => Z02_STARTPOINT,
    Z02_ENDPOINT   => Z02_ENDPOINT  ,
    Z02_MIDPOINT   => Z02_MIDPOINT  ,
    
    Z05_Y          => Z05_Y         ,
    
    run            => run           
);


flow_i: entity work.flow
Port map( 
    clk        => clk ,
    rst        => rst ,
    
    in_ready   => open,
    in_valid   => '1' ,
    out_ready  => '1' ,
    out_valid  => open,
    
    run        => run      
);
           

bezier_tb_proc: process(clk)
begin    
if rising_edge(clk) then    
if rst = '0' then
    if run(0) = '1' then
        Z00_X <= resize(Z00_X + 0.01, Z00_X);
    end if;
end if;
end if;
end process;
end Behavioral;