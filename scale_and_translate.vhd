----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity scale_and_translate is
generic (
    PROCESS_BW : integer := 18
);
Port ( 
    clk     : in STD_LOGIC;
    rst     : in STD_LOGIC;
    run     : in Std_LOGIC_VECTOR(1 downto 0);
    
    Z00_linear      : in  sfixed(1 downto -PROCESS_BW + 2);
    Z00_scaleFactor : in  sfixed(1 downto -PROCESS_BW + 2);
    Z01_bias        : in  sfixed(1 downto -PROCESS_BW + 2);
    Z02_scaledTranslated : out sfixed(1 downto -PROCESS_BW + 2)
    
    );
           
end scale_and_translate;

architecture Behavioral of scale_and_translate is
    
signal Z01_scaled           : sfixed(1 downto -PROCESS_BW + 2);

begin
scaleAndTranslate: process(clk)
begin
if rising_edge(clk) then  
    if rst = '0' then           
        if run(Z00) = '1' then
            Z01_scaled   <= resize(Z00_linear * Z00_scaleFactor, Z01_scaled, fixed_wrap, fixed_truncate);
        end if;
        
        if run(Z01) = '1' then
            Z02_scaledTranslated <= resize(Z01_scaled + Z01_bias, Z01_scaled, fixed_wrap, fixed_truncate);
        end if;     
        
    end if;
end if;
end process;

end Behavioral;