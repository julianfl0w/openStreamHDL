-- Julian Loiacono
-- stream_gate

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity stream_gate Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		din_ready : Out Std_logic := '1';
		din_valid : In Std_logic;
		din_data : In Std_logic_vector;

		dout_ready : In Std_logic;
		dout_valid : Out Std_logic := '0';
		dout_data : Out Std_logic_vector := (Others => '0')

	);
End stream_gate;

Architecture arch_imp Of stream_gate Is
	Constant ratio : Integer := din_data'length / dout_data'length;
	Signal din_ready_int : Std_logic := '1';
	Signal dout_valid_int : Std_logic := '0';
	Signal data_latched : Std_logic_vector(din_data'high Downto 0);
	Signal currOutWord : Integer := 0;

Begin
	-- Big Endian
	dout_data <= data_latched(din_data'high Downto din_data'length - dout_data'length);
	dout_valid <= dout_valid_int;
	din_ready <= din_ready_int;
	din_ready_int <= Not rst When currOutWord = 0 And (dout_valid_int = '0' Or dout_ready = '1') Else '0';

	ser_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			-- every send, derease currOutWord, and shift latched result
			If dout_valid_int = '1' And dout_ready = '1' Then
				data_latched(dout_data'high Downto 0) <= (Others => '0');
				data_latched(din_data'high Downto dout_data'length) <= data_latched(din_data'high - dout_data'length Downto 0);
				If currOutWord = 0 Then
					dout_valid_int <= '0';
				Else
					currOutWord <= currOutWord - 1;
				End If;
			End If;

			-- every receive, relatch the value
			If din_valid = '1' And din_ready_int = '1' Then
				currOutWord <= ratio - 1;
				data_latched <= din_data;
				dout_valid_int <= '1';
			End If;

		End If;
	End Process;

End arch_imp;