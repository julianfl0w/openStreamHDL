-- Simple Dual-Port Block RAM with One Clock
-- Correct Modelization with a Shared Variable
-- File:simple_dual_one_clock.vhd
-- UG901 p116
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;
ENTITY simple_dual_one_clock IS
	PORT (
		clk    : IN std_logic;
		wren   : IN std_logic;
		rden   : IN std_logic;
		wea    : IN std_logic;
		wraddr : IN  std_logic_vector;
		rdaddr : IN  std_logic_vector;
		wrdata : IN  std_logic_vector;
		rddata : OUT std_logic_vector 
	);
END simple_dual_one_clock;
ARCHITECTURE syn OF simple_dual_one_clock IS TYPE ram_type IS ARRAY (2**wraddr'length-1 DOWNTO 0) OF std_logic_vector(wrdata'length-1 DOWNTO 0);
	SHARED VARIABLE RAM : ram_type := (others=>(others=>'0'));
BEGIN
	PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN 
			IF wren = '1' THEN 
				IF wea = '1' THEN 
					RAM(conv_integer(wraddr)) := wrdata;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	PROCESS (clk) BEGIN
	IF clk'EVENT AND clk = '1' THEN
		IF rden = '1' THEN
			rddata <= RAM(conv_integer(rdaddr));
		END IF;
	END IF;
	END PROCESS;
END syn;