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
-- exports the quadratic bezier at that point

entity bezier is
Generic(
    IN_BW  : integer := 18;
    OUT_BW : integer := 18
);
Port ( 
    clk       : in STD_LOGIC;
    rst       : in STD_LOGIC;
    
    Z00_X    : in sfixed;
        
    Z02_STARTPOINT: in sfixed;
    -- midpoint needs to be doubled
    -- Z02_MIDPOINT  : in sfixed(2 downto -IN_BW + 3) := (others=>'0');
    Z02_MIDPOINT  : in sfixed;
    Z02_ENDPOINT  : in sfixed;
    
    Z05_Y    : out sfixed(1 downto -OUT_BW + 2) := (others=>'0');
    
    run : in std_logic_vector(4 downto 0)
    );
           
end bezier;

architecture Behavioral of bezier is

constant dub0unsigned : unsigned(1 downto 0) := "00";
constant dub0slv      : std_logic_vector(1 downto 0) := "00";

attribute mark_debug : string;
attribute keep : string;

signal Z01_ONE_MINUS_T    : sfixed(1 downto -IN_BW + 2) := (others=>'0');
signal Z01_T              : sfixed(1 downto -IN_BW + 2) := (others=>'0');

signal Z02_A        : sfixed(1 downto -OUT_BW + 2) := (others=>'0');
signal Z02_B        : sfixed(1 downto -OUT_BW + 2) := (others=>'0');
signal Z02_C        : sfixed(1 downto -OUT_BW + 2) := (others=>'0');
signal Z03_D        : sfixed(1 downto -IN_BW + 2) := (others=>'0');
signal Z03_E        : sfixed(1 downto -IN_BW + 2) := (others=>'0');
signal Z03_F        : sfixed(1 downto -IN_BW + 2) := (others=>'0');
signal Z04_F        : sfixed(1 downto -OUT_BW + 2) := (others=>'0');
signal Z04_SUMA     : sfixed(1 downto -OUT_BW + 2) := (others=>'0');

signal Z02_A_slv    : std_logic_vector(OUT_BW - 1 downto 0) := (others=>'0');
signal Z02_B_slv    : std_logic_vector(OUT_BW - 1 downto 0) := (others=>'0');
signal Z02_C_slv    : std_logic_vector(OUT_BW - 1 downto 0) := (others=>'0');

begin
Z02_A_slv <= to_slv(Z02_A);
Z02_B_slv <= to_slv(Z02_B);
Z02_C_slv <= to_slv(Z02_C);


bezier_proc: process(clk)
begin    
if rising_edge(clk) then    
if rst = '0' then
-- Bezier curves:
-- from wikipedia:
-- B(t) = P0(1-t)^2 + 2*P1*(1-t)*t + P2*t^2
-- assume P0x = 0, P1x = .5, P2x = 1 => B(t)x = t, then 
-- B(t)y = StartY(1-t)^2 + 2*MidY*(1-t)*t + EndY*t^2
-- or, B(t)y = StartY*A + 2*MidY*B + EndY*C
-- ot, B(t)y = D + E + F

    --  calculate t and 1-t values
    -- increasing these values to 25-bit breaks the sfixed multiplier 
    if run(Z00) = '1' then
        Z01_T           <= resize(abs(Z00_X), Z01_T);
        Z01_ONE_MINUS_T <= resize(1.0 - abs(Z00_X), Z01_ONE_MINUS_T);
    end if;
    
    if run(Z01) = '1' then
        Z02_A <= resize(Z01_ONE_MINUS_T * Z01_ONE_MINUS_T, Z02_A, fixed_wrap, fixed_truncate);
        Z02_B <= resize(Z01_ONE_MINUS_T * Z01_T          , Z02_B, fixed_wrap, fixed_truncate);
        Z02_C <= resize(Z01_T           * Z01_T          , Z02_C, fixed_wrap, fixed_truncate);
    end if;
    
    if run(Z02) = '1' then
        Z03_E <= resize(Z02_B * Z02_MIDPOINT * 2,   Z03_E, fixed_wrap, fixed_truncate);
        -- use the set startpoint and endpoint
        Z03_F <= resize(Z02_C * Z02_ENDPOINT,   Z03_F, fixed_wrap, fixed_truncate);
        Z03_D <= resize(Z02_A * Z02_STARTPOINT, Z03_D, fixed_wrap, fixed_truncate);
    end if;
    
    if run(Z03) = '1' then
        Z04_SUMA <= resize(Z03_D + Z03_E, Z04_SUMA, fixed_saturate, fixed_truncate);
        Z04_F <= resize(Z03_F, Z04_F);
    end if;
    
    if run(Z04) = '1' then
        Z05_Y   <= resize(Z04_SUMA + Z04_F, Z04_SUMA, fixed_saturate, fixed_truncate);
    end if;
end if;
end if;
end process;
end Behavioral;