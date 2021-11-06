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

Entity mm_volume Is
	Generic (
		DOUT_DATA_LEN : Integer := 18
	);
	Port (
		run : In Std_logic_vector;
		clk : In Std_logic;

		gain_wr : In Std_logic := '1';
		mm_voiceno : In Std_logic_vector;
		mm_wrdata_processbw : In Std_logic_vector;
		Z00_NoteIndex : In Std_logic_vector;

		Z02_din_data : In sfixed;
		Z03_dout_data : Out sfixed := (Others => '0')
	);

End mm_volume;

Architecture arch_imp Of mm_volume Is

	Signal Z01_gain : Std_logic_vector(mm_wrdata_processbw'high Downto 0);
	Signal Z02_gain : sfixed(1 Downto -mm_wrdata_processbw'length + 2);

Begin
	-- master gain
	gain : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceno,
			wrdata => mm_wrdata_processbw,
			wren => gain_wr,
			rden => run(Z00),
			rdaddr => Z00_NoteIndex,
			rddata => Z01_gain
		);
	sineproc :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If run(Z01) = '1' Then
				Z02_gain <= sfixed(Z01_gain);
			End If;

			If run(Z02) = '1' Then
				Z03_dout_data <= resize(Z02_din_data * Z02_gain, 1, -DOUT_DATA_LEN + 2, fixed_saturate, fixed_truncate);
			End If;

		End If;
	End Process;

End arch_imp;