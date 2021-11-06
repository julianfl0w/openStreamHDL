------------------------------------------------------------------
--
-- INVERTER
--    NAME     : JOSHUA NATIVIDAD
--    ID#      : 10795006
--    EMAIL    : SENYOR.GWAPO@YAHOO.COM
--    TEACHER  : PROF. ANALYN M. NAGAYO
--    SCHOOL   : DE LA SALLE UNIVERSITY, TAFT AVENUE, MANILA
--    FILENAME : INV1.VHD
--
-- DESCRIPTION:
--   An inverter creates an output signal that negates its input.
--
--   This is a multipurpose INVERTER design that can be instantiated
--   as a component in any architecture.
--  
--   
-- BLOCK DIAGRAM:
--
--            +-----+
--            ¦     ¦
--   A >>---->+ INV +---->> B
--            ¦     ¦
--            +-----+
--
-- TRUTH TABLE
-- +-------+--------+
-- ¦ INPUT ¦ OUTPUT ¦
-- +-------+--------+
-- ¦   0   ¦    1   ¦
-- ¦   1   ¦    0   ¦
-- +-------+--------+
--
-- BOOLEAN FUNCTION:
--
-- B = NOT A
--
------------------------------------------------------------------
--
-- VHDL IMPLEMENTATION
--
------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL; 

entity INV1 is
port (A: in STD_LOGIC;
      B: out STD_LOGIC
      );
end INV1; 

architecture BEHAVIORAL of INV1 is
begin
  B <= NOT A;
end BEHAVIORAL;
------------------------------------------------------------------