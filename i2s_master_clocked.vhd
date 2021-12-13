----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- 
-- Module Name: i2s_master_clocked - Behavioral
--
-- Description: Convert the 16-bit samples to an I2S bitstream, synced to the 
--              supplied mclk, bclk and lrclk. The value of 'sample_left' and 
--              'sample_right' on the first '0' cycle of 'lrclk' are sent.  
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.VComponents.all;
Library UNIMACRO;
use UNIMACRO.vcomponents.all;

Library work;
use work.zconstants_pkg.all;

entity i2s_master_clocked is
    generic(
           BIT_DEPTH     : integer := 16;
           CHANNEL_COUNT : integer := 2;
           INPUT_FREQ    : integer := 100e6;
           SAMPLE_RATE   : integer := 96e3;
           MCLK_PRECISION: integer := 25;
           mclk_lr_ratio : integer := 384;
           DATA_DELAY_CLOCKS: integer := 0
    );
    Port (
           i2s_mclk          : in  STD_LOGIC;
           rst          : in  STD_LOGIC;
           
           TX_VALID     : in  STD_LOGIC;
           TX_READY     : out STD_LOGIC;
           TX_DATA      : in  STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0);
           
           RX_VALID     : out STD_LOGIC;
           RX_READY     : in  STD_LOGIC;
           RX_DATA      : out STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0) := (others=>'0');
           
           i2s_bclk     : out STD_LOGIC;
           i2s_lrclk    : out STD_LOGIC := '1';
           i2s_dacsd    : out STD_LOGIC := '0';
           i2s_adcsd    : in  STD_LOGIC;
           
           i2s_begin    : out STD_LOGIC := '0'
           );
end i2s_master_clocked;

architecture Behavioral of i2s_master_clocked is

signal lrclk_last : std_logic := '0';
signal curr_bit   : integer  := 0;
signal TX_DATA_latched :  STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0);

attribute mark_debug : string;
-- mclk is 192x the sample rate
-- /2 for half-period
attribute keep : string;
constant mclk_bclk_ratio  : integer := mclk_lr_ratio / (CHANNEL_COUNT * BIT_DEPTH);

-- constant mclk_increment   : unsigned(MCLK_PRECISION-1 downto 0) := to_unsigned(2**MCLK_PRECISION * (mclk_lr_ratio*2) *SAMPLE_RATE/INPUT_FREQ, MCLK_PRECISION);
-- Synthesis hates the above
-- constant mclk_increment   : unsigned(MCLK_PRECISION-1 downto 0) := resize(X"0bf7b5b", MCLK_PRECISION);

signal bclk_counter       : integer := 0;
signal i2s_bclk_int       : std_logic := '0';
signal TX_READY_int       : STD_LOGIC;

--attribute mark_debug of i2s_bclk_int : signal is "true";
--attribute mark_debug of TX_DATA  : signal is "true";
--attribute mark_debug of TX_READY : signal is "true";
--attribute mark_debug of TX_VALID : signal is "true";
    
begin
i2s_bclk  <= i2s_bclk_int;
TX_READY  <= TX_READY_int;

dac_proc: process(i2s_mclk)
begin
    if falling_edge(i2s_mclk) then
        if rst = '0' then     
            if TX_READY_int = '1' and TX_VALID = '1' then
                TX_READY_int <= '0';
                TX_DATA_latched <= TX_DATA;
            end if;
            
            RX_VALID  <= '0';
            i2s_begin <= '0';
            
            bclk_counter <= bclk_counter + 1;
            if bclk_counter = mclk_bclk_ratio/2 - 1 then
                bclk_counter <= 0;
                i2s_bclk_int <= not i2s_bclk_int;
                
                -- change data on falling edge
                if i2s_bclk_int = '1' then
                    i2s_dacsd <= TX_DATA_latched(curr_bit);
                    -- Shift the bits out on the falling edge of bclk
                    curr_bit  <= curr_bit - 1;
                    
                    -- at the end, load next value
                    if curr_bit = 0 then   
                        -- indicate cycle beginning now
                        i2s_begin <= '1';
                        curr_bit <= BIT_DEPTH*CHANNEL_COUNT-1;
                        -- what the flippin flip, CS4344 for 24bit is actually aligned (16bit is not?)
                        TX_READY_int <= '1';   
                    end if;
                    
                    if curr_bit = ((BIT_DEPTH*CHANNEL_COUNT) + DATA_DELAY_CLOCKS) mod (BIT_DEPTH*CHANNEL_COUNT) then
                        i2s_lrclk <= '1';    
                    end if;
                    
                    if curr_bit = (BIT_DEPTH*CHANNEL_COUNT)/2 + DATA_DELAY_CLOCKS then
                        i2s_lrclk <= '0';    
                    end if;
                -- sample bit on rising edge
                else
                    RX_DATA(curr_bit) <= i2s_adcsd;
                    if curr_bit = 0 then
                        RX_VALID <= '1';
                    end if;
                end if;
            end if;
        end if;
    end if;
end process;

end Behavioral;
