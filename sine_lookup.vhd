----------------------------------------------------------------------------------
-- Julian Loiacono 6/2016
--
-- Module Name: sine lookup
----------------------------------------------------------------------------------
Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;

Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Library work;
Use work.spectral_pkg.All;

Entity sine_lookup Is
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		passthrough : In Std_logic; -- passes phase instead of sine. good for assessing word loss
		Z00_PHASE : In signed;
		Z06_SINE_out : Out sfixed := (Others => '0');
		run : In Std_logic_vector
	);

End sine_lookup;

Architecture Behavioral Of sine_lookup Is

	Constant LUT_ADDRWIDTH : Natural := 7;
	-- just leave it constant
	Constant PROCESS_BW : Integer := 18;

	Signal Z06_SINE_out_int : sfixed(Z06_SINE_out'high Downto Z06_SINE_out'low) := (Others => '0');
	Type phase_passthrough_array Is Array(Z01 To Z05) Of signed(Z06_SINE_out'length - 1 Downto 0);
	Signal phase_passthrough : phase_passthrough_array;
	Signal Z06_phase_passthrough : sfixed(Z06_SINE_out'high Downto Z06_SINE_out'low) := (Others => '0');

	Signal Z00_PHASE_QUAD_LOW : signed(1 Downto 0) := (Others => '0');
	Signal Z00_PHASE_MAIN_LOW : signed(LUT_ADDRWIDTH - 1 Downto 0) := (Others => '0');
	Signal Z01_PHASE_QUAD_HIGH : signed(1 Downto 0) := (Others => '0');
	Signal Z01_PHASE_MAIN_HIGH : signed(LUT_ADDRWIDTH - 1 Downto 0) := (Others => '0');
	Signal Z01_PHASE_HIGH : signed(Z00_PHASE'length - 1 Downto 0) := (Others => '0');
	Signal Z01_LOW : sfixed(0 Downto -PROCESS_BW + 1) := (Others => '0');
	Signal Z02_LOW : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z03_LOW : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z02_HIGH : sfixed(0 Downto -PROCESS_BW + 1) := (Others => '0');
	Signal Z03_HIGH : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z01_PHASE_RESIDUAL : sfixed(0 Downto -Z00_PHASE'length + LUT_ADDRWIDTH + 2) := (Others => '0');
	Signal Z02_PHASE_RESIDUAL : sfixed(0 Downto -Z00_PHASE'length + LUT_ADDRWIDTH + 2) := (Others => '0');
	Signal Z03_PHASE_RESIDUAL : sfixed(0 Downto -Z00_PHASE'length + LUT_ADDRWIDTH + 2) := (Others => '0');

	Signal Z03_run : Std_logic_vector(run'high - Z03 Downto 0);

Begin

	Z03_run <= run(run'high Downto Z03);
	Z00_PHASE_QUAD_LOW <= Z00_PHASE(Z00_PHASE'length - 1 Downto Z00_PHASE'length - 2);
	Z00_PHASE_MAIN_LOW <= Z00_PHASE(Z00_PHASE'length - 3 Downto Z00_PHASE'length - LUT_ADDRWIDTH - 2);
	Z01_PHASE_QUAD_HIGH <= Z01_PHASE_HIGH(Z00_PHASE'length - 1 Downto Z00_PHASE'length - 2);
	Z01_PHASE_MAIN_HIGH <= Z01_PHASE_HIGH(Z00_PHASE'length - 3 Downto Z00_PHASE'length - LUT_ADDRWIDTH - 2);
	Z06_SINE_out <= Z06_SINE_out_int When passthrough = '0' Else Z06_phase_passthrough;

	i_linear_interp : Entity work.linear_interp

		Generic Map(
			PROCESS_BW => PROCESS_BW
		)

		Port Map(
			clk => clk,
			rst => rst,
			Z00_A => Z03_LOW,
			Z00_B => Z03_HIGH,
			Z00_PHASE_in => Z03_PHASE_RESIDUAL,
			Z03_Interp_Out => Z06_SINE_out_int,
			run => Z03_run
		);

	phase_proc : Process (clk)
	Begin
		If rising_edge(clk) Then
			If run(Z00) = '1' Then
				phase_passthrough(Z01) <= Z00_PHASE(Z06_SINE_out'length - 1 Downto 0);
				-- increase PHASE_IN by the smallest amount that will result in a different read from the LUT
				Z01_PHASE_HIGH <= Z00_PHASE + (2 ** (Z00_PHASE'length - 9));
				Z01_PHASE_RESIDUAL <= sfixed('0' & Z00_PHASE(Z00_PHASE'length - 10 Downto 0));

				Case Z00_PHASE_QUAD_LOW Is
					When "00" => -- q1: straight lookup
						Z01_LOW <= sfixed(signed('0' & the_sine_lut(to_integer(unsigned(Z00_PHASE_MAIN_LOW)))));
					When "01" => -- q2: lookup(2**9-index)
						Z01_LOW <= sfixed(signed('0' & the_sine_lut(to_integer(unsigned(-Z00_PHASE_MAIN_LOW)))));
					When "10" => -- q3: -lookup
						Z01_LOW <= sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(Z00_PHASE_MAIN_LOW)))));
					When Others => -- q4  -lookup(2**9 -index)
						Z01_LOW <= sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(-Z00_PHASE_MAIN_LOW)))));
				End Case;
				--special case if residual is 0
				If Z00_PHASE(Z00_PHASE'length - 3 Downto Z00_PHASE'length - 9) = 0 And Z00_PHASE(Z00_PHASE'length - 2) = '1' Then
					If Z00_PHASE(Z00_PHASE'length - 1) = '0' Then
						Z01_LOW <= to_sfixed(0.5, Z01_LOW);
					Else
						Z01_LOW <= to_sfixed(-0.5, Z01_LOW);
					End If;
				End If;
			End If;

			If run(Z01) = '1' Then
				Z02_LOW <= Z01_LOW;
				Case Z01_PHASE_QUAD_HIGH Is
					When "00" => -- q1: straight lookup
						Z02_HIGH <= sfixed(signed('0' & the_sine_lut(to_integer(unsigned(Z01_PHASE_MAIN_HIGH)))));
					When "01" => -- q2: lookup(2**9-index)
						Z02_HIGH <= sfixed(signed('0' & the_sine_lut(to_integer(unsigned(-Z01_PHASE_MAIN_HIGH)))));
					When "10" => -- q3: -lookup
						Z02_HIGH <= sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(Z01_PHASE_MAIN_HIGH)))));
					When Others => -- q4  -lookup(2**9 -index)
						Z02_HIGH <= sfixed(-signed('0' & the_sine_lut(to_integer(unsigned(-Z01_PHASE_MAIN_HIGH)))));
				End Case;
				--special case if LUT address is 0
				If Z01_PHASE_MAIN_HIGH = 0 And Z01_PHASE_HIGH(Z00_PHASE'length - 2) = '1' Then
					If Z01_PHASE_HIGH(Z00_PHASE'length - 1) = '0' Then
						Z02_HIGH <= to_sfixed(0.5, Z02_HIGH);
					Else
						Z02_HIGH <= to_sfixed(-0.5, Z02_HIGH);
					End If;
				End If;

				Z02_PHASE_RESIDUAL <= Z01_PHASE_RESIDUAL;
			End If;

			If run(Z02) = '1' Then
				Z03_LOW <= Z02_LOW;
				Z03_HIGH <= Z02_HIGH;
				Z03_PHASE_RESIDUAL <= Z02_PHASE_RESIDUAL;
			End If;

			If run(Z05) = '1' Then
				Z06_phase_passthrough <= sfixed(phase_passthrough(Z05));
			End If;

			passthroughloop :
			For i In Z02 To phase_passthrough'high Loop
				If run(i - 1) = '1' Then
					phase_passthrough(i) <= phase_passthrough(i - 1);
				End If;
			End Loop;
		End If;
	End Process;

End Behavioral;