library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;
Library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee_proposed.fixed_float_types.all;

-- maclauren expansion of the power function
-- https://www.math24.net/power-series-expansions

entity power is
generic (
    PROCESS_BW         : integer := 18;
    Z00_NATLOG_OF_Base : real    := 0.00057762265 -- ln(2^(1/1200))
);
port (
    clk: in std_logic;
    rst: in std_logic;
    
    run: in std_logic_vector;
    Z00_Exponent : in sfixed(13 downto 0);
    Z06_rslt     : out sfixed(PROCESS_BW downto -PROCESS_BW+2)
    );
end power;

architecture arch_imp of power is

signal Z01_xlna   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z02_xlna   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z03_xlna   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z04_xlna   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z05_xlna   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');

signal Z02_xlna2  : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z03_xlna3  : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z04_xlna4  : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z05_xlna5  : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');

signal Z01_rslt   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z02_rslt   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z03_rslt   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z04_rslt   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');
signal Z05_rslt   : sfixed(PROCESS_BW downto -PROCESS_BW+2) := (others=>'0');

constant Z00_NATLOG_OF_Basesf   : sfixed(-6 downto -PROCESS_BW+1-6) := to_sfixed(Z00_NATLOG_OF_Base, -6, -PROCESS_BW+1-6);

begin

process (clk)
begin
  if rising_edge(clk) then 
    if rst = '0' then
    
        if run(Z00) = '1' then
            Z01_xlna <= resize(Z00_Exponent*Z00_NATLOG_OF_Basesf , Z01_xlna, fixed_wrap, fixed_round );
            Z01_rslt <= to_sfixed(1, Z01_rslt);
        end if;
        if run(Z01) = '1' then
            Z02_xlna  <= resize(Z01_xlna*to_sfixed(1.0 / 2.0, Z01_xlna), Z02_xlna, fixed_wrap, fixed_round );
            Z02_xlna2 <= resize(Z01_xlna*Z01_xlna, Z02_xlna, fixed_wrap, fixed_round );
            Z02_rslt  <= resize(Z01_rslt+Z01_xlna, Z02_rslt, fixed_wrap, fixed_round );
        end if;
        if run(Z02) = '1' then
            Z03_xlna  <= resize(Z02_xlna*to_sfixed(1.0 / 3.0, Z01_xlna), Z03_xlna, fixed_wrap, fixed_round );
            Z03_xlna3 <= resize(Z02_xlna*Z02_xlna2, Z03_xlna, fixed_wrap, fixed_round );
            Z03_rslt  <= resize(Z02_rslt+Z02_xlna2, Z03_rslt, fixed_wrap, fixed_round );
        end if;
        if run(Z03) = '1' then
            Z04_xlna  <= resize(Z03_xlna*to_sfixed(1.0 / 4.0, Z01_xlna), Z04_xlna, fixed_wrap, fixed_round );
            Z04_xlna4 <= resize(Z03_xlna*Z03_xlna3, Z04_xlna, fixed_wrap, fixed_round );
            Z04_rslt  <= resize(Z03_rslt+Z03_xlna3, Z04_rslt, fixed_wrap, fixed_round );
        end if;
        if run(Z04) = '1' then
            Z05_xlna  <= resize(Z04_xlna*to_sfixed(1.0 / 5.0, Z01_xlna), Z05_xlna, fixed_wrap, fixed_round );
            Z05_xlna5 <= resize(Z04_xlna*Z04_xlna4, Z05_xlna, fixed_wrap, fixed_round );
            Z05_rslt  <= resize(Z04_rslt+Z04_xlna4, Z05_rslt, fixed_wrap, fixed_round );
        end if;
        if run(Z05) = '1' then
            Z06_rslt  <= resize(Z05_rslt+Z05_xlna5, Z05_rslt, fixed_wrap, fixed_round );
        end if;
    end if;
  end if;
end process;

end arch_imp;