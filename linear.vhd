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
-- exports the quadratic linear at that point

entity linear is
Generic(
    IN_BW  : integer := 18;
    OUT_BW : integer := 18;
    PROCESS_BW : integer := 18;
    linear_BW  : integer := 10
);
Port ( 
    clk       : in STD_LOGIC;
    rst       : in STD_LOGIC;
    
    Z00_X    : in sfixed;
        
    Z00_STARTPOINT: in sfixed;
    Z00_ENDPOINT  : in sfixed;
    
    Z03_Y    : out sfixed(1 downto -OUT_BW + 2) := (others=>'0');
    
    run : in std_logic_vector(4 downto 0)
    );
           
end linear;

architecture Behavioral of linear is

signal Z01_STARTPOINT  : sfixed(Z00_STARTPOINT'high downto Z00_STARTPOINT'low) := (others=>'0');
signal Z02_STARTPOINT  : sfixed(Z00_STARTPOINT'high downto Z00_STARTPOINT'low) := (others=>'0');

signal Z01_DIFF : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
signal Z02_DIFFADJ : sfixed(1 downto -OUT_BW + 2) := (others=>'0');

signal Z01_X : sfixed(Z00_X'high downto Z00_X'low) := (others=>'0');

begin  

phase_proc: process(clk)
begin
if rising_edge(clk) then
    
    if run(Z00) = '1' then
        Z01_DIFF <= resize(Z00_ENDPOINT - Z00_STARTPOINT, Z01_DIFF, fixed_wrap, fixed_round);
        Z01_X <= Z00_X;
        Z01_STARTPOINT <= Z00_STARTPOINT;
    end if;
    
    if run(Z01) = '1' then
        Z02_DIFFADJ <= resize(Z01_DIFF * Z01_X, Z02_DIFFADJ, fixed_wrap, fixed_round);
        Z02_STARTPOINT <= Z01_STARTPOINT;
    end if;
    
    if run(Z02) = '1' then
        Z03_Y <= resize(Z02_STARTPOINT + Z02_DIFFADJ, 1, -OUT_BW + 2, fixed_wrap, fixed_round );
    end if;
    
end if;
end process;

end Behavioral;