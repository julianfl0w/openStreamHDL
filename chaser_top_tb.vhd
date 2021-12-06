library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;

library IEEE_PROPOSED;
use IEEE_PROPOSED.FIXED_PKG.ALL;

-- chaser_top_tb 

entity chaser_top_tb is
end chaser_top_tb;

architecture arch_imp of chaser_top_tb is

signal clk         : STD_LOGIC := '0';
signal sclk        : STD_LOGIC := '0';
signal initialize_rst         : STD_LOGIC := '1';
signal halt        : STD_LOGIC;

signal SPI_SCLK    : std_logic; -- SPI clock
signal SPI_CS_N    : std_logic := '1'; -- SPI chip select, active in low
signal SPI_MOSI    : std_logic_vector(0 downto 0); -- SPI serial data from master to slave
signal SPI_MISO    : std_logic_vector(0 downto 0); -- SPI serial data from slave to master

signal i2s_bclk    : STD_LOGIC;
signal i2s_lrclk   : STD_LOGIC := '1';
signal i2s_dacsd   : STD_LOGIC := '0';
signal i2s_adcsd   : STD_LOGIC;

signal irqueue_out_valid : std_logic;
signal audio_out_valid   : std_logic := '0';


signal i_cmd64bit_data   : std_logic_vector(63 downto 0);  -- data to sent
signal i_cmd64bit_valid  : std_logic := '0';  -- start TX on serial line
signal i_cmd64bit_ready   : STD_LOGIC;

signal TX_LengthIn_data   : std_logic_vector(63 downto 0) := (others=>'0');
signal TX_LengthIn_ready  : std_logic := '0';
signal TX_LengthIn_valid  : std_logic := '0';
  
signal spi_tx_valid    : std_logic := '0';  -- start TX on serial line
signal spi_tx_ready    : std_logic;  -- TX data completed; spi_rx_data available
signal spi_tx_data     : std_logic_vector(63 downto 0);  -- data to sent
signal spi_rx_data     : std_logic_vector(63 downto 0);  -- received data
signal spi_rx_valid    : std_logic := '0'; 

signal voiceno   : integer;
signal opno   : integer;
signal currentbyte : integer := 7;

constant HWIDTH : integer := 1;

signal btn    :  Std_logic_vector(1 Downto 0) := (Others => '0');
signal led    :  Std_logic_vector(1 Downto 0) := (Others => '0');
signal led0_b :  Std_logic := '1';
signal led0_g :  Std_logic := '1';
signal led0_r :  Std_logic := '1';
		
-- Calculate the number of clock cycles in minutes/seconds
function format_command_32(mm_paramno : integer := 0;
                    mm_voiceaddr        : integer := 0;
                    payload        : std_logic_vector
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_voiceaddr, 24)) &
        payload;
end function;
    
-- Calculate the number of clock cycles in minutes/seconds
function format_command_real(mm_paramno  : integer := 0;
                    mm_voiceaddr : integer := 0;
                    payload        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_voiceaddr, 24)) &
        b"00000000000000" & 
        std_logic_vector(to_sfixed(payload, 1, -18+2));
end function;
    
-- to be used with bezier middle and enpoint
-- (start point is set as current state of envelope)
function format_command_bezier_MIDnEND(mm_paramno  : integer := 0;
                    mm_voiceaddr : integer := 0;
                    midpoint        : real := 0.0;
                    endpoint        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_voiceaddr, 24)) &
        b"000000000000" &
        std_logic_vector(to_sfixed(midpoint, 1, -10+2)) & 
        std_logic_vector(to_sfixed(endpoint, 1, -10+2));
end function;
    
function format_command_3bezier_targets(mm_paramno  : integer := 0;
                    mm_voiceaddr : integer := 0;
                    bt0        : real := 0.0;
                    bt1        : real := 0.0;
                    bt2        : real := 0.0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(mm_paramno, 8)) & 
        std_logic_vector(to_unsigned(mm_voiceaddr, 24)) &
        b"00" &
        std_logic_vector(to_sfixed(bt0, 1, -10+2)) & 
        std_logic_vector(to_sfixed(bt1, 1, -10+2)) &
        std_logic_vector(to_sfixed(bt2, 1, -10+2));
end function;
    
    
-- integer payload 
function format_command_int(mm_paramno  : integer := 0;
                    mm_operator  : integer := 0;
                    mm_voiceaddr : integer := 0;
                    payload        : integer := 0
                    ) return std_logic_vector is
    variable TotalSeconds : integer;
begin
    return std_logic_vector(to_unsigned(mm_paramno, 8)) & 
           std_logic_vector(to_unsigned(mm_operator, 8)) & 
           std_logic_vector(to_unsigned(mm_voiceaddr, 16)) &
           std_logic_vector(to_unsigned(payload, 32));
end function;
    
-- integer payload 
function format_command_2payloads(
                    payload0        : integer := 0;
                    payload1        : integer := 0
                    ) return std_logic_vector is
begin
    return std_logic_vector(to_unsigned(payload0, 32)) &
           std_logic_vector(to_unsigned(payload1, 32));
end function;
    
    
begin
i2s_adcsd <= i2s_dacsd; -- loopback for testing

clk <= not clk after 41.5ns; -- 12MHz clock on Cmod A7
sclk <= not sclk after 8ns; -- 120MHz sclk
--sclk <= clk;
--clk <= not clk after 5ns; -- 12MHz clock on Cmod A7

dut: entity work.chaser_top
--generic map(
--    USE_MLMM   => 0
--)
port map (
    sysclk    => clk  ,
    rstin     => initialize_rst  ,
    
    SPI_SCLK      => SPI_SCLK      ,
    SPI_CS_N      => SPI_CS_N      ,
    SPI_MOSI      => SPI_MOSI      ,
    SPI_MISO      => SPI_MISO      ,
    
    irqueue_out_valid => irqueue_out_valid,
    audio_out_valid   => audio_out_valid  ,
    
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
   rst       => initialize_rst,
   Clk       => sclk,
   
   TX_LengthIn_data   => TX_LengthIn_data ,
   TX_LengthIn_ready  => TX_LengthIn_ready,
   TX_LengthIn_valid  => TX_LengthIn_valid,
   
   -- TX (MOSI) Signals
   TX_data   => spi_tx_data,
   TX_valid  => spi_tx_valid,
   TX_Ready  => spi_tx_ready,
   
   -- RX (MISO) Signals
   RX_valid  => spi_rx_valid,
   RX_ready  => '1',
   RX_data   => spi_rx_data,

   -- SPI Interface
   SPI_Clk   => SPI_SCLK,
   SPI_Cs    => SPI_CS_N,
   SPI_MISO  => SPI_MISO,
   SPI_MOSI  => SPI_MOSI
    );
    
-- cpu replacement process
process
begin
initialize_rst <= '1';
for ii in 0 to 300 loop
wait until rising_edge(sclk);
end loop;
initialize_rst <= '0';
for ii in 0 to 300 loop
wait until rising_edge(sclk);
end loop;
initialize_rst <= '0';
wait until halt = '0';
for ii in 0 to 300 loop
wait until rising_edge(sclk);
end loop;

-- only considering note 0 for now
voiceno    <= 0;
opno <= 1; -- 1 << 0
i_cmd64bit_valid <= '1';
TX_LengthIn_valid<= '1';
-- test vector
--i_cmd64bit_data  <=  X"F0AA55BB66CC77F0"; wait until rising_edge(sclk);
TX_LengthIn_data <= std_logic_vector(to_unsigned(8*8, 64));
i_cmd64bit_data  <=  X"FF00FF00FF00FFFF"; wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_env_clkdiv     , opno, voiceno, 5); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_readid, 1, 0, 0); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(0, 0, 0, 0); wait until rising_edge(sclk); 

i_cmd64bit_data  <=  format_command_int(cmd_static, 0, voiceno, 192); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_sounding, 0, voiceno, 1); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_fm_algo, 0, voiceno, 16777215); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_am_algo, 0, voiceno, 0); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_fbsrc, 0, voiceno, 0); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_fbgain, 0, voiceno, 2**9); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_softreset, 0, 0, 0); wait until rising_edge(sclk);

--TX_LengthIn_data <= std_logic_vector(to_unsigned(24*8, 64));
i_cmd64bit_data  <=  format_command_int(cmd_channelgain, 1, voiceno, 2**16); wait until rising_edge(sclk); -- ONEHOT! 0 for passthrough
i_cmd64bit_data  <=  format_command_int(cmd_channelgain, 2, voiceno, 2**16); wait until rising_edge(sclk); -- 2**16 for passthrough
-- Gain
i_cmd64bit_data  <=  format_command_int(cmd_env      , opno, voiceno, 2**16); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_env_rate, opno, voiceno, 2**12); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_envexp   , opno, voiceno, 1); wait until rising_edge(sclk); 

-- Frequency
i_cmd64bit_data  <=  format_command_int(cmd_increment_rate, opno, voiceno, 2**12); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_increment      , opno, voiceno, 2**27); wait until rising_edge(sclk); -- 32 bit incrementer
i_cmd64bit_data  <=  format_command_int(cmd_incexp  , opno, voiceno, 1); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_am_algo, opno, voiceno, 0); wait until rising_edge(sclk); 

--- Various OPTIONS START
-- set up an FM oscillator
opno <= 2; -- 1 << 1 wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_fm_algo, 0, voiceno, 16777208); wait until rising_edge(sclk); -- FOR FEEDBACK TESTING
i_cmd64bit_data  <=  format_command_int(cmd_fm_algo, 0, voiceno, 16777209); wait until rising_edge(sclk); -- FOR FM TESTING
-- Vibrato test
--opno <= 128; -- 1<<7 -- write the prev one twice, idgaf
-- VARIOUS OPTIONS END

wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_envexp   , opno, voiceno, 1); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_env      , opno, voiceno, 2**14); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_env_rate, opno, voiceno, 2**12); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_increment      , opno, voiceno, 2**24); wait until rising_edge(sclk); -- 32 bit incrementer
--i_cmd64bit_data  <=  format_command_int(cmd_incexp  , opno, voiceno, 1); wait until rising_edge(sclk); 
--i_cmd64bit_data  <=  format_command_int(cmd_increment_rate, opno, voiceno, 2**12); wait until rising_edge(sclk); 

-- turn off flush
i_cmd64bit_data  <=  format_command_int(cmd_flushspi, 0, 0, 0); wait until rising_edge(sclk); 
i_cmd64bit_data  <=  format_command_int(cmd_passthrough, 0, 0, 0); wait until rising_edge(sclk);  -- 0 for 1 op, 1 voice passthrough
i_cmd64bit_data  <=  format_command_int(cmd_shift, 0, 0, 5); wait until rising_edge(sclk);  -- 0 for 1 op, 1 voice passthrough

TX_LengthIn_valid<= '0';

i_cmd64bit_valid <= '0';
        
wait until rising_edge(sclk);    
for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;
i_cmd64bit_valid <= '1';
TX_LengthIn_valid<= '1';
i_cmd64bit_data  <=  format_command_int(cmd_flushspi, 0, 0, 0); wait until rising_edge(sclk); 
TX_LengthIn_valid<= '0';
i_cmd64bit_valid <= '0';
for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;

wait until rising_edge(sclk); 
for ii in 0 to 500000 loop
    -- wait for the queue to complete
    for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;
    wait until spi_tx_valid = '0';
    for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;

    i_cmd64bit_valid <= '1';
    TX_LengthIn_valid<= '1';
    if irqueue_out_valid = '1' then 
        i_cmd64bit_data  <=  format_command_int(cmd_readirqueue, 1, 0, 0); wait until rising_edge(sclk); 
        i_cmd64bit_data  <=  format_command_int(cmd_readirqueue, 0, 0, 0); wait until rising_edge(sclk);
    else
      i_cmd64bit_data  <=  format_command_int(cmd_readaudio, 1, 0, 0); wait until rising_edge(sclk); 
      i_cmd64bit_data  <=  format_command_int(cmd_readaudio, 0, 0, 0); wait until rising_edge(sclk); 
    end if;
    TX_LengthIn_valid<= '0';
    i_cmd64bit_valid <= '0';
    
    -- hopefully the spi implementation has some time at the end of spi read
    for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;
    wait until spi_tx_valid = '0';
    for iii in 0 to 100 loop wait until rising_edge(sclk); end loop;
    
    i_cmd64bit_valid <= '1';
    TX_LengthIn_valid<= '1';
    -- perform the read, if indicated
    i_cmd64bit_data  <=  format_command_int(0, 0, 0, 0); wait until rising_edge(sclk); 
    TX_LengthIn_valid<= '0';
    i_cmd64bit_valid <= '0';

end loop;
i_cmd64bit_valid <= '0';
TX_LengthIn_valid<= '0';

wait;
end process;

fs0: entity work.fifo_stream_36
    PORT MAP (
        clk        => sclk        ,
        rst        => initialize_rst  ,
        din_ready  => i_cmd64bit_ready  ,
        din_valid  => i_cmd64bit_valid  ,
        din_data   => i_cmd64bit_data   ,
        dout_ready => spi_tx_ready  ,
        dout_valid => spi_tx_valid  ,
        dout_data  => spi_tx_data   
    );
    
end arch_imp;