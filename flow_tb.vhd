----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.uniform;
use ieee.math_real.floor;

entity flow_tb is
end flow_tb;

architecture Behavioral of flow_tb is

signal clk       : STD_LOGIC := '0';
signal rst       : STD_LOGIC := '0';
signal in_ready  : STD_LOGIC := '0';
signal in_valid  : STD_LOGIC := '0';
signal out_ready : STD_LOGIC := '0';
signal out_valid : STD_LOGIC := '0';
signal run       : std_logic_vector(10 downto 0) := (others=>'0');
    
begin

clk <= not clk after 10ns;

dut: entity work.flow
Port map( 
    clk        => clk      ,
    rst        => rst      ,
    
    in_ready   => in_ready ,
    in_valid   => in_valid ,
    out_ready  => out_ready,
    out_valid  => out_valid,
    
    run        => run      
);
           
runproc: process(clk) is
    variable seed1 : positive := 1;
    variable seed2 : positive := 1;
    variable r : real;
    variable y : integer;
begin
if rising_edge(clk) then  
    if in_ready = '1' then
        in_valid  <= '0';    
    end if;
    out_ready <= '0';
    if rst = '0' then
        uniform(seed1, seed2, r);
        if r < 0.1 then
            in_valid <= '1';
        end if;
        
        uniform(seed1, seed2, r);
        if r < 0.1 then
            out_ready <= '1';
        end if;
    end if;
end if;
end process;
end Behavioral;