----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity flow_override is
Port ( 
    clk       : in STD_LOGIC;
    rst       : in STD_LOGIC;

    in_ready  : out STD_LOGIC;
    in_valid  : in STD_LOGIC;
    out_ready : in STD_LOGIC;
    out_valid : out STD_LOGIC;
    
    valid_override : in std_logic_vector;
    run            : out std_logic_vector
    );
           
end flow_override;

architecture Behavioral of flow_override is

signal run_int  : std_logic_vector(run'range) := (others=>'0');
signal valid    : std_logic_vector(run'length-1 downto 0) := (others=>'0');
signal valid_no_override   : std_logic_vector(run'length-1 downto 0) := (others=>'0');
signal future_gap: std_logic_vector(run'range) := (others=>'0');

begin
run       <= run_int;
in_ready  <= future_gap(0)   and not rst;
out_valid <= valid(run'high) and not rst;

run_int(0)    <= future_gap(0) and in_valid and not rst;
future_gap(0) <=  '1' when ((not unsigned(valid(run'high downto 1))) /= 0 or out_ready = '1') else '0';
genloop:
for i in 1 to run'high generate
    -- future gap if there is a non-valid ahead, or if output is ready
    future_gap(i) <= '1' when ((not unsigned(valid(run'high downto i+1))) /= 0 or out_ready = '1') else '0';
    -- run when there is a gap and current step is valid
    run_int(i)    <= future_gap(i) and valid(i) and not rst;
end generate;

valid <= valid_no_override and not valid_override;
runproc: process(clk)
begin
if rising_edge(clk) then  
    if rst = '0' then
        valid_no_override(1) <= not valid_no_override(0) and ((in_valid and future_gap(0)) or (valid_no_override(1) and not run_int(1)));
        for i in 2 to run'length-1 loop
            -- current step is valid if previous step ran, or current step was valid and didnt run
            -- and not validity override
            valid_no_override(i) <= (valid_no_override(i-1) and run_int(i-1)) or (valid_no_override(i) and not run_int(i));
        end loop;
    else
        valid_no_override <= (others=>'0');
    end if;
end if;
end process;
end Behavioral;