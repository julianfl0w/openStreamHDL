----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;
Use ieee.math_real.All;

Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;
Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity sum8 Is
	Port (
		run : In Std_logic_vector;
		clk : In Std_logic;

		Z00_all8 : In OPERATOR_PROCESS;
		Z03_sum_out : Out sfixed(4 Downto -PROCESS_BW + 2)
	);

End sum8;

Architecture arch_imp Of sum8 Is

	Signal Z01_Op0_Op1 : sfixed(2 Downto -PROCESS_BW + 2);
	Signal Z01_Op2_Op3 : sfixed(2 Downto -PROCESS_BW + 2);
	Signal Z01_Op4_Op5 : sfixed(2 Downto -PROCESS_BW + 2);
	Signal Z02_0123 : sfixed(3 Downto -PROCESS_BW + 2);
	Signal Z02_4567 : sfixed(3 Downto -PROCESS_BW + 2);

Begin

	sineproc :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If run(Z00) = '1' Then
				-- start summing over attenuated outputs
				Z01_Op0_Op1 <= resize((Z00_all8(0) + Z00_all8(1)), Z01_Op0_Op1, fixed_wrap, fixed_truncate);
				Z01_Op2_Op3 <= resize((Z00_all8(2) + Z00_all8(3)), Z01_Op0_Op1, fixed_wrap, fixed_truncate);
				Z01_Op4_Op5 <= resize((Z00_all8(4) + Z00_all8(5)), Z01_Op0_Op1, fixed_wrap, fixed_truncate);
				--Z01_Op0_Op1 <= resize(Z00_all8(0) + Z00_all8(1), Z01_Op0_Op1, fixed_saturate, fixed_truncate);
			End If;

			If run(Z01) = '1' Then
				Z02_0123 <= resize((Z01_Op0_Op1 + Z01_Op2_Op3), Z02_0123, fixed_wrap, fixed_truncate);
				Z02_4567 <= resize(Z01_Op4_Op5, Z02_4567, fixed_wrap, fixed_truncate);
			End If;

			If run(Z02) = '1' Then
				Z03_sum_out <= resize((Z02_0123 + Z02_4567), 4, -PROCESS_BW + 2, fixed_wrap, fixed_truncate);
			End If;

		End If;
	End Process;

End arch_imp;