----------------------------------------------------------------------------------
-- Julian Loiacono 6/2016
--
-- Module Name: sine lookup
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee_proposed.fixed_float_types.all;

library work;
use work.spectral_pkg.all;

entity sine_lookup is 
Port ( 
    clk          : in STD_LOGIC;
    rst          : in STD_LOGIC;
    passthrough  : in STD_LOGIC; -- passes phase instead of sine. good for assessing word loss
    Z00_PHASE    : in  signed;
    Z06_SINE_out : out sfixed := (others=>'0');
    run          : in std_logic_vector
    );
           
end sine_lookup;

architecture Behavioral of sine_lookup is

constant LUT_ADDRWIDTH : natural := 7;
 -- just leave it constant
constant PROCESS_BW  : integer := 18;

signal Z06_SINE_out_int : sfixed(Z06_SINE_out'high downto Z06_SINE_out'low) := (others=>'0');
type phase_passthrough_array is array(Z01 to Z05) of signed(Z06_SINE_out'length-1 downto 0);
signal phase_passthrough : phase_passthrough_array;
signal Z06_phase_passthrough : sfixed(Z06_SINE_out'high downto Z06_SINE_out'low) := (others=>'0');

signal Z00_PHASE_QUAD_LOW  : signed(1 downto 0)               := (others=>'0');
signal Z00_PHASE_MAIN_LOW  : signed(LUT_ADDRWIDTH-1 downto 0) := (others=>'0');
signal Z01_PHASE_QUAD_HIGH : signed(1 downto 0)               := (others=>'0');
signal Z01_PHASE_MAIN_HIGH : signed(LUT_ADDRWIDTH-1 downto 0) := (others=>'0');
signal Z01_PHASE_HIGH : signed(Z00_PHASE'length - 1 downto 0) := (others=>'0');
signal Z01_LOW  : sfixed(0 downto -PROCESS_BW + 1) := (others=>'0');
signal Z02_LOW  : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
signal Z03_LOW  : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');
signal Z02_HIGH : sfixed(0 downto -PROCESS_BW + 1) := (others=>'0');
signal Z03_HIGH : sfixed(1 downto -PROCESS_BW + 2) := (others=>'0');


signal Z01_PHASE_RESIDUAL : sfixed(0 downto -Z00_PHASE'length+LUT_ADDRWIDTH+2) := (others=>'0');
signal Z02_PHASE_RESIDUAL : sfixed(0 downto -Z00_PHASE'length+LUT_ADDRWIDTH+2) := (others=>'0');
signal Z03_PHASE_RESIDUAL : sfixed(0 downto -Z00_PHASE'length+LUT_ADDRWIDTH+2) := (others=>'0');

signal Z03_run : std_logic_vector(run'high-Z03 downto 0);

begin 

Z03_run <= run(run'high downto Z03);
Z00_PHASE_QUAD_LOW <= Z00_PHASE(Z00_PHASE'length-1 downto Z00_PHASE'length-2);
Z00_PHASE_MAIN_LOW <= Z00_PHASE(Z00_PHASE'length-3 downto Z00_PHASE'length-LUT_ADDRWIDTH-2);
Z01_PHASE_QUAD_HIGH <= Z01_PHASE_HIGH(Z00_PHASE'length-1 downto Z00_PHASE'length-2);
Z01_PHASE_MAIN_HIGH <= Z01_PHASE_HIGH(Z00_PHASE'length-3 downto Z00_PHASE'length-LUT_ADDRWIDTH-2);
Z06_SINE_out <= Z06_SINE_out_int when passthrough = '0' else Z06_phase_passthrough;

i_linear_interp : entity work.linear_interp 

Generic map(
    PROCESS_BW=> PROCESS_BW
    )

Port Map ( 
    clk         => clk,
    rst         => rst,
    Z00_A => Z03_LOW,
    Z00_B => Z03_HIGH,
    Z00_PHASE_in   => Z03_PHASE_RESIDUAL,
    Z03_Interp_Out => Z06_SINE_out_int,
    run => Z03_run
    );

phase_proc: process(clk)
begin
if rising_edge(clk) then
    if run(Z00) = '1' then
        phase_passthrough(Z01) <= Z00_PHASE(Z06_SINE_out'length-1 downto 0);
        -- increase PHASE_IN by the smallest amount that will result in a different read from the LUT
        Z01_PHASE_HIGH <= Z00_PHASE + (2**(Z00_PHASE'length-9));
        Z01_PHASE_RESIDUAL <= sfixed('0' & Z00_PHASE(Z00_PHASE'length-10 downto 0));
    
        case Z00_PHASE_QUAD_LOW is
        when "00" =>  -- q1: straight lookup
            Z01_LOW <=  sfixed( signed('0' & the_sine_lut(to_integer(unsigned( Z00_PHASE_MAIN_LOW)))));
        when "01" =>  -- q2: lookup(2**9-index)
            Z01_LOW <=  sfixed( signed('0' & the_sine_lut(to_integer(unsigned(-Z00_PHASE_MAIN_LOW)))));
        when "10" =>  -- q3: -lookup
            Z01_LOW <=  sfixed(-signed('0' & the_sine_lut(to_integer(unsigned( Z00_PHASE_MAIN_LOW)))));
        when others =>-- q4  -lookup(2**9 -index)
            Z01_LOW <=  sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(-Z00_PHASE_MAIN_LOW)))));
        end case;
        --special case if residual is 0
        if Z00_PHASE(Z00_PHASE'length-3 downto Z00_PHASE'length-9) = 0 and Z00_PHASE(Z00_PHASE'length-2) = '1' then
            if Z00_PHASE(Z00_PHASE'length-1) = '0' then
                Z01_LOW <= to_sfixed(0.5, Z01_LOW);
            else
                Z01_LOW <= to_sfixed(-0.5, Z01_LOW);
            end if;
        end if;
    end if;
    
    if run(Z01) = '1' then
        Z02_LOW <= Z01_LOW;
        case Z01_PHASE_QUAD_HIGH is
        when "00" =>  -- q1: straight lookup
            Z02_HIGH <=  sfixed( signed('0' & the_sine_lut(to_integer(unsigned( Z01_PHASE_MAIN_HIGH)))));
        when "01" =>  -- q2: lookup(2**9-index)
            Z02_HIGH <=  sfixed( signed('0' & the_sine_lut(to_integer(unsigned(-Z01_PHASE_MAIN_HIGH)))));
        when "10" =>  -- q3: -lookup
            Z02_HIGH <=  sfixed(-signed('0' & the_sine_lut(to_integer(unsigned( Z01_PHASE_MAIN_HIGH)))));
        when others =>-- q4  -lookup(2**9 -index)
            Z02_HIGH <=  sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(-Z01_PHASE_MAIN_HIGH)))));
        end case;
        --special case if LUT address is 0
        if Z01_PHASE_MAIN_HIGH = 0 and Z01_PHASE_HIGH(Z00_PHASE'length-2) = '1' then
            if Z01_PHASE_HIGH(Z00_PHASE'length-1) = '0' then
                Z02_HIGH <= to_sfixed(0.5, Z02_HIGH);
            else
                Z02_HIGH <= to_sfixed(-0.5, Z02_HIGH);
            end if;
        end if;
        
        Z02_PHASE_RESIDUAL <= Z01_PHASE_RESIDUAL;
    end if;
    
    if run(Z02) = '1' then
        Z03_LOW <= Z02_LOW;
        Z03_HIGH <= Z02_HIGH;
        Z03_PHASE_RESIDUAL <= Z02_PHASE_RESIDUAL;
    end if;
    
    if run(Z05) = '1' then
        Z06_phase_passthrough <= sfixed(phase_passthrough(Z05));
    end if;
    
    passthroughloop :
    For i In Z02 To phase_passthrough'high Loop
        If run(i - 1) = '1' Then
            phase_passthrough(i) <= phase_passthrough(i - 1);
        End If;
    End Loop;
end if;
end process;

end Behavioral;