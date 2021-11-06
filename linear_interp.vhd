----------------------------------------------------------------------------------
-- Julian Loiacono 6/2016
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

library work;
use work.spectral_pkg.all;

entity linear_interp is
Generic(
    PROCESS_BW: integer := 18
    );
Port ( 
    clk       : in STD_LOGIC;
    rst       : in STD_LOGIC;
    Z00_A : in sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
    Z00_B : in sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
    Z00_PHASE_in : in  sfixed;
    Z03_Interp_Out : out sfixed := (others=>'0');
    run : in std_logic_vector
    );
           
end linear_interp;

architecture Behavioral of linear_interp is

signal Z01_A  : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
signal Z02_A  : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');

signal Z01_DIFF : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
signal Z02_DIFFADJ : sfixed(1 downto Z03_Interp_Out'low) := (others=>'0');

signal Z01_PHASE : sfixed(Z00_PHASE_in'high downto Z00_PHASE_in'low) := (others=>'0');

begin 

phase_proc: process(clk)
begin
if rising_edge(clk) then

    if run(Z00) = '1' then
        Z01_DIFF <= resize(Z00_B - Z00_A, Z01_DIFF, fixed_wrap, fixed_round);
        Z01_PHASE <= sfixed(Z00_PHASE_in);
        Z01_A <= Z00_A;
    end if;
    
    if run(Z01) = '1' then
        Z02_DIFFADJ <= resize(Z01_DIFF * Z01_PHASE, Z02_DIFFADJ, fixed_wrap, fixed_round);
        Z02_A <= Z01_A;
    end if;
    
    if run(Z02) = '1' then
        Z03_Interp_Out <= resize(Z02_A + Z02_DIFFADJ, 1, -18 + 2, fixed_wrap, fixed_round );
    end if;
    
end if;
end process;

end Behavioral;