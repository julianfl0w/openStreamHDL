library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- envelope_tb is intended to be used to create bezier shapes in the spectral domain
-- it can be used for ex. harmonic width, global filter, or note filter
-- the path looks like the following

-- control [0, 1) -> 3 bezier curves -> 2d bezier -> out

entity envelope_tb is
end envelope_tb;

architecture arch_imp of envelope_tb is

constant NOTECOUNT : integer := 1024;
constant PROCESS_BW : integer := 18;
constant CTRL_COUNT : integer := 4;
    
signal clk         : STD_LOGIC := '0';
signal rst         : STD_LOGIC := '1';

signal speed_wr      : STD_LOGIC := '0';   
signal speed_wraddr  : STD_LOGIC_VECTOR (integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');            
signal mm_wrdata  : STD_LOGIC_VECTOR (PROCESS_BW-1 downto 0) := (others=>'0');           
signal env_finished_ready   : std_logic := '0'; 
signal env_finished_valid   : std_logic := '0';
signal env_finished_addr    : STD_LOGIC_VECTOR (integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');  
signal mm_wraddr : STD_LOGIC_VECTOR (integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');            
signal env_bezier_BEGnMIDnENDpoint_wr   : std_logic := '0';
signal Z00_ADDR    : STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');   
signal Z03_ENV_OUT : sfixed( 1 downto -PROCESS_BW+2) := (others=>'0');    
signal run         : std_logic_vector(7 downto 0) := (others=>'0');   

begin

clk <= not clk after 10ns;

dut: entity work.envelope
port map (
    clk         =>  clk        ,
    rst         =>  rst        ,
    
    speed_wr      =>  speed_wr     ,
    speed_wraddr  =>  speed_wraddr ,
    mm_wrdata  =>  mm_wrdata ,
    env_finished_ready   =>  env_finished_ready  ,
    env_finished_valid   =>  env_finished_valid  ,
    env_finished_addr    =>  env_finished_addr   ,
    
    Z00_ADDR    =>  Z00_ADDR   ,
    Z03_ENV_OUT =>  Z03_ENV_OUT,
    run         =>  run        ,
    mm_wraddr => mm_wraddr,
    env_bezier_BEGnMIDnENDpoint_wr      => env_bezier_BEGnMIDnENDpoint_wr
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

-- cpu replacement process
process
begin
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
wait until rising_edge(clk);
rst <= '0';
wait until rising_edge(clk);
wait until rising_edge(clk);
    mm_wrdata <= std_logic_vector(to_sfixed(0.01, 1, -mm_wrdata'length +2));
    speed_wr     <= '1';
wait until rising_edge(clk);
    speed_wr     <= '0';
wait until rising_edge(clk);
wait until rising_edge(clk);
wait;
end process;

-- addr inc process

addrproc: process(clk)
begin
if rising_edge(clk) then      
    if run(Z00) = '1' then
        Z00_ADDR   <= std_logic_vector(unsigned(Z00_ADDR) + 1); 
    end if;
end if;
end process;

end arch_imp;