-- Simple Dual-Port Block RAM with One Clock
-- Correct Modelization with a Shared Variable
-- File:simple_dual_one_clock.vhd
-- UG901 p116
Library IEEE;
Use IEEE.std_logic_1164.All;
Use IEEE.std_logic_unsigned.All;
Entity simple_dual_one_clock Is
	Port (
		clk : In Std_logic;
		wren : In Std_logic;
		rden : In Std_logic;
		wea : In Std_logic;
		wraddr : In Std_logic_vector;
		rdaddr : In Std_logic_vector;
		wrdata : In Std_logic_vector;
		rddata : Out Std_logic_vector
	);
End simple_dual_one_clock;
Architecture syn Of simple_dual_one_clock Is Type ram_type Is Array (2 ** wraddr'length - 1 Downto 0) Of Std_logic_vector(wrdata'length - 1 Downto 0);
	Shared Variable RAM : ram_type := (Others => (Others => '0'));
Begin
	Process (clk)
	Begin
		If clk'EVENT And clk = '1' Then
			If wren = '1' Then
				If wea = '1' Then
					RAM(conv_integer(wraddr)) := wrdata;
				End If;
			End If;
		End If;
	End Process;
	Process (clk) Begin
		If clk'EVENT And clk = '1' Then
			If rden = '1' Then
				rddata <= RAM(conv_integer(rdaddr));
			End If;
		End If;
	End Process;
End syn;