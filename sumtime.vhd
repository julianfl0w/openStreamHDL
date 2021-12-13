-- Sums across time
-- Julian Loiacono

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;

Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity sumtime Is
	Generic (
		ratio : Integer := 1024
	);

	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		din_ready : Out Std_logic := '1';
		din_valid : In Std_logic;
		din_data : In sfixed;

		dout_ready : In Std_logic;
		dout_valid : Out Std_logic := '0';
		dout_data : Out sfixed := (Others => '0')

	);
End sumtime;

Architecture arch_imp Of sumtime Is

	Constant ratiolog2 : Integer := integer(round(log2(real(ratio))));
	Signal din_ready_int : Std_logic := '1';
	Signal dout_valid_int : Std_logic := '0';
	Signal data_latched : sfixed(dout_data'high Downto dout_data'low) := (Others => '0');
	Signal currAddend : Integer := ratio - 1;

Begin
	dout_data <= data_latched;
	dout_valid <= dout_valid_int;
	din_ready <= din_ready_int;
	din_ready_int <= '1' When dout_valid_int = '0' Or dout_ready = '1' Else '0';

	ser_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			-- every send, invalidate and reset output
			If dout_valid_int = '1' And dout_ready = '1' Then
				dout_valid_int <= '0';
				data_latched <= (Others => '0');
			End If;

			-- every receive, add the bit
			If din_valid = '1' And din_ready_int = '1' Then
				-- if sending, reset
				If dout_valid_int = '1' And dout_ready = '1' Then
					data_latched <= resize(din_data, data_latched, fixed_wrap, fixed_truncate);
				Else
					data_latched <= resize(data_latched + din_data, data_latched, fixed_wrap, fixed_truncate);
				End If;
				If currAddend = 0 Then
					currAddend <= ratio - 1;
					dout_valid_int <= '1';
				Else
					currAddend <= currAddend - 1;
				End If;
			End If;

		End If;
	End Process;

End arch_imp;