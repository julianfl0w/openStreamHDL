----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Entity flow Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		in_ready : Out Std_logic;
		in_valid : In Std_logic;
		out_ready : In Std_logic;
		out_valid : Out Std_logic;

		run : Out Std_logic_vector
	);

End flow;

Architecture Behavioral Of flow Is

	Signal run_int    : Std_logic_vector(run'Range) := (Others => '0');
	Signal valid      : Std_logic_vector(run'length - 1 Downto 1) := (Others => '0');
	Signal future_gap : Std_logic_vector(run'Range) := (Others => '0');

Begin
	run <= run_int;
	in_ready <= future_gap(0) And Not rst;
	out_valid <= valid(run'high) And Not rst;

	run_int(0) <= future_gap(0) And in_valid And Not rst;
	future_gap(0) <= '1' When ((Not unsigned(valid(run'high Downto 1))) /= 0 Or out_ready = '1') Else '0';
	genloop :
	For i In 1 To run'high-1 Generate
		-- future gap if there is a non-valid ahead, or if output is ready
		future_gap(i) <= '1' When ((Not unsigned(valid(run'high Downto i + 1))) /= 0 Or out_ready = '1') Else '0';
	End Generate;
    future_gap(run'high) <= out_ready;

    genloop2 :
	For i In 1 To run'high Generate
		-- run when there is a gap and current step is valid
		run_int(i) <= future_gap(i) And valid(i) And Not rst;
	End Generate;

	runproc : Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
				valid(1) <= (in_valid And future_gap(0)) Or (valid(1) And Not run_int(1));
				For i In 2 To run'length - 1 Loop
					-- current step is valid if previous step ran, or current step was valid and didnt run
					valid(i) <= (valid(i - 1) And run_int(i - 1)) Or (valid(i) And Not run_int(i));
				End Loop;
			Else
				valid <= (Others => '0');
			End If;
		End If;
	End Process;
End Behavioral;