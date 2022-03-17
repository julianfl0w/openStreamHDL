library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- spectral_engine_tb 

entity spectral_engine_tb is
end spectral_engine_tb;

architecture arch_imp of spectral_engine_tb is

signal clk         : STD_LOGIC := '0';
signal rst         : STD_LOGIC := '1';
signal din_ready   : STD_LOGIC;
signal halt        : STD_LOGIC;

signal SCLK        : std_logic; -- SPI clock
signal CS_N        : std_logic := '1'; -- SPI chip select, active in low
signal MOSI        : std_logic; -- SPI serial data from master to slave
signal MISO        : std_logic; -- SPI serial data from slave to master

signal i2s_bclk    : STD_LOGIC;
signal i2s_lrclk   : STD_LOGIC := '1';
signal i2s_dacsd   : STD_LOGIC := '0';
signal i2s_adcsd   : STD_LOGIC;

signal spi_tx_valid    : std_logic := '0';  -- start TX on serial line
signal spi_tx_ready    : std_logic;  -- TX data completed; i_rx_data available
signal spi_tx_data     : std_logic_vector(7 downto 0);  -- data to sent
signal i_rx_data       : std_logic_vector(7 downto 0);  -- received data

signal i_tx_fifoin_data   : std_logic_vector(63 downto 0);  -- data to sent
signal i_tx_fifoin_valid  : std_logic := '0';  -- start TX on serial line

signal i_tx_fifoout_data   : std_logic_vector(63 downto 0);  -- data to sent
signal i_tx_fifoout_data_r   : std_logic_vector(63 downto 0);  -- data to sent
signal i_tx_fifoout_valid  : std_logic := '0';
signal i_tx_fifoout_ready  : std_logic := '1'; 
signal i_rx_valid          : std_logic := '0'; 

signal mm_noteno    : integer;
signal currentbyte : integer := 7;

constant HWIDTH : integer := 1;


signal btn    :  Std_logic_vector(1 Downto 0) := (Others => '0');
signal led    :  Std_logic_vector(1 Downto 0) := (Others => '0');
signal led0_b :  Std_logic := '1';
signal led0_g :  Std_logic := '1';
signal led0_r :  Std_logic := '1';
		
-- Calculate the number of clock cycles in minutes/seconds
function format_command_32(mm_noteno  : integer := 0;
                    mm_paramno     : integer := 0;
                    mm_additional0 : integer := 0;
                    mm_additional1 : integer := 0;
                    payload        : std_logic_vector
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_noteno, 8)) & 
        std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_additional0, 8)) & 
        std_logic_vector(to_unsigned(mm_additional1, 8)) &
        payload;
end function;
    
-- Calculate the number of clock cycles in minutes/seconds
function format_command(mm_noteno  : integer := 0;
                    mm_paramno     : integer := 0;
                    mm_additional0 : integer := 0;
                    mm_additional1 : integer := 0;
                    payload        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_noteno, 8)) & 
        std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_additional0, 8)) & 
        std_logic_vector(to_unsigned(mm_additional1, 8)) &
        b"00000000000000" & 
        std_logic_vector(to_sfixed(payload, 1, -18+2));
end function;
    
-- to be used with bezier middle and enpoint
-- (start point is set as current state of envelope)
function format_command_bezier_MIDnEND(mm_noteno  : integer := 0;
                    mm_paramno     : integer := 0;
                    mm_additional0 : integer := 0;
                    mm_additional1 : integer := 0;
                    midpoint        : real := 0.0;
                    endpoint        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_noteno, 8)) & 
        std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_additional0, 8)) & 
        std_logic_vector(to_unsigned(mm_additional1, 8)) &
        b"000000000000" &
        std_logic_vector(to_sfixed(midpoint, 1, -10+2)) & 
        std_logic_vector(to_sfixed(endpoint, 1, -10+2));
end function;
    
function format_command_3bezier_targets(mm_noteno  : integer := 0;
                    mm_paramno     : integer := 0;
                    mm_additional0 : integer := 0;
                    mm_additional1 : integer := 0;
                    bt0        : real := 0.0;
                    bt1        : real := 0.0;
                    bt2        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_noteno, 8)) & 
        std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_additional0, 8)) & 
        std_logic_vector(to_unsigned(mm_additional1, 8)) &
        b"00" &
        std_logic_vector(to_sfixed(bt0, 1, -10+2)) & 
        std_logic_vector(to_sfixed(bt1, 1, -10+2)) &
        std_logic_vector(to_sfixed(bt2, 1, -10+2));
end function;
    
    
-- integer payload 
function format_command_int(mm_noteno  : integer := 0;
                    mm_paramno     : integer := 0;
                    mm_additional0 : integer := 0;
                    mm_additional1 : integer := 0;
                    payload        : integer := 0
                    ) return std_logic_vector is
    variable TotalSeconds : integer;
begin
    return std_logic_vector(to_unsigned(mm_noteno, 8)) & 
        std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_additional0, 8)) & 
        std_logic_vector(to_unsigned(mm_additional1, 8)) &
        std_logic_vector(to_unsigned(payload, 32));
end function;
    
type tb_statetype is (IDLE, WAIT0, SENDING);
signal spi_state : tb_statetype := IDLE;

begin

clk <= not clk after 41.5ns; -- 12MHz clock on Cmod A7
--clk <= not clk after 5ns; -- 12MHz clock on Cmod A7

dut: entity work.spectral_engine
--generic map(
--    USE_MLMM   => 0
--)
port map (
    sysclk    => clk       ,
    rstin     => rst       ,
    
    SCLK      => SCLK      ,
    CS_N      => CS_N      ,
    MOSI      => MOSI      ,
    MISO      => MISO      ,
    
    i2s_bclk  => i2s_bclk  ,
    i2s_lrclk => i2s_lrclk ,
    i2s_dacsd => i2s_dacsd ,
    i2s_adcsd => i2s_adcsd ,
    
	btn    => btn    ,
	led    => led    ,
	led0_b => led0_b ,
	led0_g => led0_g ,
	led0_r => led0_r ,
	
	halt => halt
);


spimaster: entity work.spi_master
 port map (
   -- Control/Data Signals,
   Rst       => rst,
   Clk       => clk,
   
   BYTES_PER_SEND => 8,
   -- TX (MOSI) Signals
   TX_data   => spi_tx_data,
   TX_valid  => spi_tx_valid,
   TX_Ready  => spi_tx_ready,
   
   -- RX (MISO) Signals
   RX_valid  => i_rx_valid,
   RX_ready  => '1',
   RX_data   => i_rx_data,

   -- SPI Interface
   SPI_Clk   => SCLK,
   SPI_Cs    => CS_N,
   SPI_MISO  => MISO,
   SPI_MOSI  => MOSI
    );
    
-- cpu replacement process
process
begin
rst <= '1';
for ii in 0 to 60 loop
wait until rising_edge(clk);
end loop;
rst <= '0';
wait until halt = '0';
for ii in 0 to 50 loop
wait until rising_edge(clk);
end loop;

-- only considering note 0 for now
mm_noteno     <= 0;
i_tx_fifoin_valid <= '1';

-- test vector
i_tx_fifoin_data  <=  X"F0AA55BB66CC77F0"; wait until rising_edge(clk); 

-- GFILTER!
-- passthrough control options
-- write patchage speed at 0
i_tx_fifoin_data  <=  format_command(mm_noteno, GFILTER_ENV_SPEED, 0, 0, 0.5 / 32); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command_3bezier_targets(mm_noteno, GFILTER_3TARGETS, 0, 0, 1.0, 1.0, 1.0); wait until rising_edge(clk); 

-- PITCH BEND         
-- set bezier triple
-- write patchage speed at 0
--i_tx_fifoin_data  <=  format_command(mm_noteno, PBEND_ENV_SPEED, 0, 0, 0.5 / 32); wait until rising_edge(clk); 
--i_tx_fifoin_data  <=  format_command_bezier_MIDnEND(mm_noteno, PBEND_MIDnEND, 0, 0, 0.5, 1.0); wait until rising_edge(clk);   

-- Harmonic width effect!
-- write patchage speed at 0
i_tx_fifoin_data  <=  format_command(mm_noteno, HWIDTH_ENV_SPEED, 0, 0, 0.1 / 32); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command_3bezier_targets(mm_noteno, HWIDTH_3TARGETS, 0, 0, 0.5, 0.5, 1.0); wait until rising_edge(clk);  

-- NFILTER!
-- write patchage speed at 0
i_tx_fifoin_data  <=  format_command(mm_noteno, NFILTER_ENV_SPEED, 0, 0, 0.5 / 32); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command_3bezier_targets(mm_noteno, NFILTER_3TARGETS, 0, 0, 1.0, 1.0, 1.0); wait until rising_edge(clk);  
        
-- harmonic parameters
i_tx_fifoin_data  <=  format_command_int(mm_noteno, HARMONIC_WIDTH,    0, 0,   HWIDTH); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command    (mm_noteno, HARMONIC_WIDTH_INV,0, 0, real(1/HWIDTH)); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command_int(mm_noteno, HARMONIC_BASENOTE, 0, 0, 4800); wait until rising_edge(clk);
i_tx_fifoin_data  <=  format_command_32 (mm_noteno, HARMONIC_ENABLE,   0, 0, x"00010000"); wait until rising_edge(clk); 
i_tx_fifoin_data  <=  format_command_int(mm_noteno, CENTSINC, 0, 0, 5); wait until rising_edge(clk);
  

-- finally, permit the volume
--i_tx_fifoin_data  <=  format_command(mm_noteno, ENVELOPE_ENV_SPEED, 0, 0, 0.1 / 32); wait until rising_edge(clk); 
--i_tx_fifoin_data  <=  format_command_bezier_MIDnEND(mm_noteno, ENVELOPE_MIDnEND, 0, 0, 0.5, 1.0); wait until rising_edge(clk);          

i_tx_fifoin_valid <= '0';
        
wait until rising_edge(clk);    
wait;
end process;

-- if a transfer is occuring, forward data to the spi
i_tx_fifoout_ready <= '1' when spi_state = IDLE else '0';
spi_tx_valid <= '1' when spi_state = SENDING else '0';
spi_tx_data  <= i_tx_fifoout_data_r(8*(currentbyte+1)-1 downto 8*currentbyte);

spi_process:
process (clk)
begin
  if rising_edge(clk) then 
        case(spi_state) is
           when IDLE => 
                currentbyte  <= 7;
                if i_tx_fifoout_valid = '1' then
                    spi_state  <= WAIT0;
                    i_tx_fifoout_data_r <= i_tx_fifoout_data;
                end if;
           when WAIT0 =>
                spi_state  <= SENDING;
            
           when SENDING => 
                if spi_tx_ready = '1' then
                    -- read fifo when spi is ready to send
                    
                    if currentbyte > 0 then 
                        currentbyte <= (currentbyte - 1);
                    else
                        spi_state    <= IDLE;
                    end if;
                end if;
           when OTHERS=> 
        end case;
    end if;
end process;

-- send out a stream of envelopes that need reset
fs0: entity work.fifo_stream_36
    PORT MAP (
        clk        => clk        ,
        rst        => rst        ,
        din_ready  => din_ready  ,
        din_valid  => i_tx_fifoin_valid  ,
        din_data   => i_tx_fifoin_data   ,
        dout_ready => i_tx_fifoout_ready ,
        dout_valid => i_tx_fifoout_valid ,
        dout_data  => i_tx_fifoout_data  
    );
    
end arch_imp;