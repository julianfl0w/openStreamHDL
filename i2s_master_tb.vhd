----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/06/2017 04:22:18 PM
-- Design Name: 
-- Module Name: i2TX_b - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity i2s_master_tb is
--  Port ( );
end i2s_master_tb;

architecture Behavioral of i2s_master_tb is
signal srccounter : integer := 0;
constant clk_period : time := 10 ns;
constant BIT_DEPTH: integer := 24;
constant CHANNEL_COUNT: integer := 2;

signal S_ACLK       : STD_LOGIC := '0';
signal S_ARESETn    : STD_LOGIC := '0';
signal TX_VALID     : STD_LOGIC := '1';
signal TX_READY     : STD_LOGIC;
signal TX_DATA      : STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0) := (others=>'0');

type satype is array(0 to 1) of STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0);
signal sigarray : satype := (0 => X"FFFFFFFFFFFF", 1 => X"000000000000");

signal RX_VALID     : STD_LOGIC;
signal RX_READY     : STD_LOGIC := '1';
signal RX_DATA      : STD_LOGIC_VECTOR(BIT_DEPTH*CHANNEL_COUNT-1 downto 0);
           
signal i2s_bclk     : STD_LOGIC;
signal i2s_lrclk    : STD_LOGIC;
signal i2s_dacsd    : STD_LOGIC;
signal i2s_adcsd    : STD_LOGIC := '0';
signal i2s_mclk     : STD_LOGIC := '0';
signal i2s_begin    : STD_LOGIC := '0';
    
begin

------------------------------------------
-- Convert the samples into an I2S bitstream
------------------------------------------
i2s_master_i: entity work.i2s_master
generic map(
       BIT_DEPTH     => BIT_DEPTH     ,
       CHANNEL_COUNT => CHANNEL_COUNT ,
       INPUT_FREQ    => 100e6    ,
       SAMPLE_RATE   => 96e3   
)
port map (
   clk             => S_ACLK         ,
   rst             => S_ARESETn      ,
   
   TX_VALID        => TX_VALID       ,
   TX_READY        => TX_READY       ,
   TX_DATA         => TX_DATA        ,
   
   RX_VALID        => RX_VALID       ,
   RX_READY        => RX_READY       ,
   RX_DATA         => RX_DATA        ,
    
   i2s_bclk        => i2s_bclk       ,
   i2s_lrclk       => i2s_lrclk      ,
   i2s_dacsd       => i2s_dacsd      ,
   i2s_adcsd       => i2s_adcsd      ,
   i2s_mclk        => i2s_mclk       ,

   i2s_begin       => i2s_begin

); 

-- loopback test
i2s_adcsd <= i2s_dacsd;

dac_proc: process(S_ACLK)
begin
    if rising_edge(S_ACLK) then
        -- increment the data on a successful transfer
        if (TX_VALID and TX_READY) = '1' then
            --TX_DATA <= std_logic_vector(unsigned(TX_DATA) + 1);
            TX_DATA <= sigarray(srccounter);
            srccounter <= srccounter + 1;
            if srccounter = 1 then
                srccounter <= 0;
            end if;
        end if;
    end if;
end process;

S_ACLK <= not S_ACLK after clk_period/2;  --for 0.5 ns signal is '0'.

end Behavioral;
