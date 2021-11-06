library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- entity declaration for your testbench.Dont declare any ports here
ENTITY sine_lookup_tb IS 
END sine_lookup_tb;

ARCHITECTURE behavior OF sine_lookup_tb IS
-- Component Declaration for the Unit Under Test (UUT)

COMPONENT sine_lookup
--just copy and paste the input and output ports of your module as such. 
Port ( 
    clk100       : in STD_LOGIC;
    Z00_PHASE_in : in  signed(std_flowwidth - 1 downto 0);
    Z06_SINE_out : out sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
    OUTSAMPLEF_ALMOSTFULL : in std_logic
    );
       
END COMPONENT;


constant clk100_period : time := 10 ns;
signal clk100       : STD_LOGIC := '0';
--signal Z00_PHASE_in : sfixed(RAM_WIDTH18 - 1 downto 0) := (others=>'0');
signal Z00_PHASE_in : signed(std_flowwidth - 1 downto 0) := (others=>'0');
signal Z06_SINE_out : sfixed(1 downto -std_flowwidth + 2) := (others=>'0');
signal OUTSAMPLEF_ALMOSTFULL : std_logic := '0';

BEGIN
-- Instantiate the Unit Under Test (UUT)
i_sine_lookup: sine_lookup PORT MAP (
    clk100       => clk100,
    Z00_PHASE_in => Z00_PHASE_in,
    Z06_SINE_out => Z06_SINE_out,
    OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
    ); 

-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
    clk100 <= '0';
    wait for clk100_period/2;  --for 0.5 ns signal is '0'.
    clk100 <= '1';
    wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;
   
lfotest: process(clk100)
begin
    if rising_edge(clk100) then
        --Z00_PHASE_in <= Z00_PHASE_in + (2**10);
        Z00_PHASE_in <= Z00_PHASE_in + 1;
    end if;
end process;

END;