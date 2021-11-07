----------------------------------------------------------------------------------
-- Julian Loiacono 6/2016
----------------------------------------------------------------------------------
Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Library work;
Use work.zconstants_pkg.All;

Entity linear_interp Is
	Generic (
		PROCESS_BW : Integer := 18
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		Z00_A : In sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
		Z00_B : In sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
		Z00_PHASE_in : In sfixed;
		Z03_Interp_Out : Out sfixed := (Others => '0');
		run : In Std_logic_vector
	);

End linear_interp;

Architecture Behavioral Of linear_interp Is

	Signal Z01_A : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z02_A : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal Z01_DIFF : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z02_DIFFADJ : sfixed(1 Downto Z03_Interp_Out'low) := (Others => '0');

	Signal Z01_PHASE : sfixed(Z00_PHASE_in'high Downto Z00_PHASE_in'low) := (Others => '0');

Begin

	phase_proc : Process (clk)
	Begin
		If rising_edge(clk) Then

			If run(Z00) = '1' Then
				Z01_DIFF <= resize(Z00_B - Z00_A, Z01_DIFF, fixed_wrap, fixed_round);
				Z01_PHASE <= sfixed(Z00_PHASE_in);
				Z01_A <= Z00_A;
			End If;

			If run(Z01) = '1' Then
				Z02_DIFFADJ <= resize(Z01_DIFF * Z01_PHASE, Z02_DIFFADJ, fixed_wrap, fixed_round);
				Z02_A <= Z01_A;
			End If;

			If run(Z02) = '1' Then
				Z03_Interp_Out <= resize(Z02_A + Z02_DIFFADJ, 1, -18 + 2, fixed_wrap, fixed_round);
			End If;

		End If;
	End Process;

End Behavioral;