-- Splits a stream 
Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity stream_split Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		din_ready : Out Std_logic := '0';
		din_valid : In Std_logic;
		din_data : In Std_logic_vector;

		dout0_ready : In Std_logic;
		dout0_valid : Out Std_logic := '0';
		dout0_data : Out Std_logic_vector := (Others => '0');

		dout1_ready : In Std_logic;
		dout1_valid : Out Std_logic := '0';
		dout1_data : Out Std_logic_vector := (Others => '0')

	);
End stream_split;

Architecture arch_imp Of stream_split Is

	Signal din_ready_int : Std_logic := '0';
	Signal dout0_valid_int : Std_logic := '0';
	Signal dout1_valid_int : Std_logic := '0';

Begin
	din_ready <= din_ready_int;
	dout0_valid <= dout0_valid_int;
	dout1_valid <= dout1_valid_int;

	-- ready when neither output is valid
	din_ready_int <= Not dout1_valid_int And Not dout0_valid_int;

	ser_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			-- if sending, invalidate
			If dout0_valid_int = '1' And dout0_ready = '1' Then
				dout0_valid_int <= '0';
			End If;
			If dout1_valid_int = '1' And dout1_ready = '1' Then
				dout1_valid_int <= '0';
			End If;

			-- if receiving, validate
			If din_ready_int = '1' And din_valid = '1' Then
				dout0_valid_int <= '1';
				dout1_valid_int <= '1';
				dout0_data <= din_data;
				dout1_data <= din_data;
			End If;
		End If;
	End Process;
End arch_imp;