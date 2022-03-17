----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

-- This envelope file exports *SAWTOOTH ONLY* as a standard [0.1) control
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

entity envelope is
generic (
    NOTECOUNT : integer := 1024;
    PROCESS_BW : integer;
    CTRL_COUNT : integer := 4
);
Port ( 
    clk     : in STD_LOGIC;
    rst     : in STD_LOGIC;
    run     : in Std_LOGIC_VECTOR;--(2 downto 0);
       
    speed_wr  : in STD_LOGIC;   
    mm_wrdata : in STD_LOGIC_VECTOR (PROCESS_BW-1 downto 0);   
    mm_wraddr : in STD_LOGIC_VECTOR (integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');            
    
    -- output fifo to indicate when phase is at end          
    env_finished_ready   : in std_logic; 
    env_finished_valid   : out std_logic;
    env_finished_addr    : out STD_LOGIC_VECTOR (integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');  
    
    Z00_ADDR    : in STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');   
    
    Z03_reset_phase_valid: in std_logic := '0';

    --Z03_ENV_OUT : out sfixed(1 downto -PROCESS_BW + 2) := (others=>'0')
    Z03_ENV_OUT : out sfixed(1 downto -PROCESS_BW + 2)
    
    );
           
end envelope;

architecture Behavioral of envelope is
    
attribute mark_debug : string;

Constant ADDR_WIDTH : integer := integer(round(log2(real(NOTECOUNT))));

--(2^40) / (100e6 Hz) = 10995 sec
--Signal counter : unsigned(39 downto 0)  := (others=>'0');   
--(2^30) / (100e6) = 10 sec
Signal counter : unsigned(29 downto 0)  := (others=>'0');   

Signal Z01_speed: STD_LOGIC_VECTOR(PROCESS_BW-1 downto 0) := (others=>'0');  
Signal Z02_speed: sfixed(PROCESS_BW+4 downto 5) := (others=>'0');  
Signal Z01_StartTime    : STD_LOGIC_VECTOR(PROCESS_BW-1 downto 0) := (others=>'0');  
signal Z02_StartTime    : unsigned(Z01_StartTime'high downto 0) := (others=>'0');  
Signal Z04_StartTime    : STD_LOGIC_VECTOR(PROCESS_BW-1 downto 0) := (others=>'0');  
Signal Z02_TimeSinceStart  : sfixed(1 downto -PROCESS_BW) := (others=>'0');   
--Signal Z04_StartTime : STD_LOGIC_VECTOR(PROCESS_BW-1 downto 0) := (others=>'0');  

signal Z01_ADDR   : STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');  
signal Z02_ADDR   : STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');  
signal Z03_ADDR   : STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0');  
signal Z04_ADDR   : STD_LOGIC_VECTOR(integer(round(log2(real(NOTECOUNT))))-1 downto 0)  := (others=>'0'); 


signal Z04_starttime_wr  : STD_LOGIC := '0';
signal Z04_Phase_Over_wr : STD_LOGIC := '0';

signal Z01_curr_time    : unsigned(Z01_StartTime'high downto 0) := (others=>'0');   
signal Z02_curr_time    : unsigned(Z01_StartTime'high downto 0) := (others=>'0');    
signal Z03_curr_time    : unsigned(Z01_StartTime'high downto 0) := (others=>'0'); 
signal Z03_final_length : unsigned(Z01_StartTime'high downto 0) := (others=>'0');   

signal Z03_ENV_OUT_int : sfixed(1 downto -PROCESS_BW + 2)  := (others=>'0');   

signal Z04_finished  : STD_LOGIC_VECTOR(0 downto 0)  := (others=>'0');   
signal Z03_finished  : STD_LOGIC_VECTOR(0 downto 0)  := (others=>'0');   
signal Z02_finished  : STD_LOGIC_VECTOR(0 downto 0)  := (others=>'0');   
    
begin
Z03_ENV_OUT <= Z03_ENV_OUT_int;

speedram : entity work.simple_dual_one_clock
port map(
    clk   => clk  ,
    wren   => speed_wr, 
    wea   => '1'         ,
    wraddr => mm_wraddr,
    wrdata   => mm_wrdata,
    rden   => run(Z00)    ,
    rdaddr => Z00_addr,
    rddata   => Z01_speed  
);

starttimeram : entity work.simple_dual_one_clock
port map(
    clk   => clk  ,
    wea    => '1'         ,
    wren   => Z04_starttime_wr,
    wraddr => Z04_Addr,
    wrdata => Z04_StartTime,
    rden   => run(Z00)    ,
    rdaddr => Z00_addr,
    rddata => Z01_StartTime 
);

finishedram : entity work.simple_dual_one_clock
port map(
    clk    => clk  ,
    wren   => run(Z04),
    wea    => '1'         ,
    wraddr => Z04_ADDR,
    wrdata => Z04_finished,
    
    rdaddr => Z01_addr,
    rden   => run(Z01)    , 
    rddata => Z02_finished  
);
                
OSCVOICEVOL_fx: process(clk)
begin
if rising_edge(clk) then  
    counter <= counter + 1;
    Z04_starttime_wr  <= '0';
    Z04_Phase_Over_wr <= '0';
    
    if rst = '0' then           
        if run(Z00) = '1' then
            Z01_ADDR      <= Z00_ADDR;
            Z01_curr_time <= counter(counter'high downto counter'length-Z01_StartTime'length);
        end if;
        
        if run(Z01) = '1' then
            -- Env out on range [0, 1)
            Z02_ADDR     <= Z01_ADDR;
            Z02_speed    <= sfixed(Z01_speed);
            Z02_TimeSinceStart(-1 downto -Z02_TimeSinceStart'length+2) <= sfixed(Z01_curr_time - unsigned(Z01_StartTime));
            Z02_curr_time <= Z01_curr_time;
            
        end if;     
        
        if run(Z02) = '1' then
            Z03_curr_time <= Z02_curr_time;
            Z03_ADDR      <= Z02_ADDR;
            Z03_finished  <= Z02_finished;
            
            if Z02_Finished(0) = '1' then
                Z03_ENV_OUT_int  <= to_sfixed(1.0, Z03_ENV_OUT_int);
            else
                Z03_ENV_OUT_int  <= resize(Z02_TimeSinceStart*Z02_speed, Z03_ENV_OUT_int, fixed_wrap, fixed_truncate );
            end if;          
        end if;
        
        if run(Z03) = '1' then  
            Z04_ADDR      <= Z03_ADDR;
            Z04_finished  <= Z03_finished;
            -- service any incoming changes
            if Z03_reset_phase_valid = '1' then 
                Z04_StartTime   <= std_logic_vector(Z03_curr_time); -- reset this phase
                Z04_starttime_wr<= '1';
                Z04_finished(0) <= '0';
            elsif Z03_ENV_OUT_int > to_sfixed(1.0, Z03_ENV_OUT_int) then 
                Z04_finished(0) <= '1';
                Z04_Phase_Over_wr <= '1';
            end if;
        end if;
            
    end if;
end if;
end process;

-- send out a stream of envelopes that need reset
fs0: entity work.fifo_stream
    PORT MAP (
        clk        => clk        ,
        rst        => rst        ,
        din_ready  => open       ,
        din_valid  => Z04_Phase_Over_wr  ,
        din_data   => Z04_ADDR   ,
        dout_ready => env_finished_ready ,
        dout_valid => env_finished_valid ,
        dout_data  => env_finished_addr  
    );


end Behavioral;