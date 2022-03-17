----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz> 
-- Julian Loiacono 6/2016
--
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--FIFO_DUALCLOCK_MACRO : In order to incorporate this function into the design,
--     VHDL      : the following instance declaration needs to be placed
--   instance    : in the architecture body of the design code.  The
--  declaration  : (FIFO_DUALCLOCK_MACRO_inst) and/or the port declarations
--     code      : after the "=>" assignment maybe changed to properly
--               : reference and connect this function to the design.
--               : All inputs and outputs must be connected.

--    Library    : In addition to adding the instance declaration, a use
--  declaration  : statement for the UNISIM.vcomponents library needs to be
--      for      : added before the entity declaration.  This library
--    Xilinx     : contains the component declarations for all Xilinx
--   primitives  : primitives and points to the models that will be used
--               : for simulation.

--  Copy the following four statements and paste them before the
--  Entity declaration, unless they already exist.

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity ram_active_rst is
    Port ( slowclk    : in STD_LOGIC;
           rstin      : in STD_LOGIC := '0';
           clksRdy    : in STD_LOGIC;
           ram_rst    : out STD_LOGIC := '0';
           initializeRam_out0 : out std_logic := '1';
           initializeRam_out1 : out std_logic := '1'
           );
           
end ram_active_rst;

architecture Behavioral of ram_active_rst is

signal initCounterRAM : integer := 0;
signal initializeRam  : std_logic := '1';

begin

pipeline: process(slowclk)
    begin
        if rising_edge(slowclk) then
            -- initialize if need be
            if initializeRam = '1' and clksRdy = '1' then
                initCounterRAM <= initCounterRAM + 1;
                if(initCounterRAM = 5) then
                    ram_rst <= '1';
                elsif (initCounterRAM = 12) then
                    ram_rst <= '0';
                elsif initCounterRAM = 300 then 
                    initializeRAM <= '0';
                end if;
            end if;
            initializeRam_out0 <= initializeRam;
            initializeRam_out1 <= initializeRam;
            if rstin = '1' then
                initializeRam <= '0';
                initCounterRAM<= 0;
            end if;
        end if;
    end process;
    
end Behavioral;
