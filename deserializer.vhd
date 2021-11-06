-- Julian Loiacono
-- Deserializer

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity deserializer Is
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
End deserializer;

Architecture arch_imp Of deserializer Is
	Constant ratio : Integer := dout_data'length / din_data'length;
	Signal din_ready_int : Std_logic := '1';
	Signal dout_valid_int : Std_logic := '0';
	Signal data_latched : Std_logic_vector(dout_data'high Downto 0);
	Signal currInBit : Integer := ratio - 1;

Begin
	-- Big Endian
	dout_data <= data_latched;
	dout_valid <= dout_valid_int;
	din_ready <= din_ready_int;
	din_ready_int <= '1' When dout_valid_int = '0' Or dout_ready = '1' Else '0';

	ser_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
				-- every send, invalidate output
				If dout_valid_int = '1' And dout_ready = '1' Then
					dout_valid_int <= '0';
				End If;

				-- every receive, latch the bit
				If din_valid = '1' And din_ready_int = '1' Then
					data_latched <= data_latched(data_latched'high - 1 Downto 0) & din_data; -- little endian
					If currInBit = 0 Then
						currInBit <= ratio - 1;
						dout_valid_int <= '1';
					Else
						currInBit <= currInBit - 1;
					End If;
				End If;

			Else
				currInBit <= ratio - 1;
			End If;

		End If;
	End Process;

End arch_imp;