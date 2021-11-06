----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------
Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Library work;
Use work.spectral_pkg.All;

-- takes startpoint, midpoint, endpoint, and x-value (-1, 1)
-- exports the quadratic bezier at that point

Entity bezier Is
	Generic (
		IN_BW : Integer := 18;
		OUT_BW : Integer := 18
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		Z00_X : In sfixed;

		Z02_STARTPOINT : In sfixed;
		-- midpoint needs to be doubled
		-- Z02_MIDPOINT  : in sfixed(2 downto -IN_BW + 3) := (others=>'0');
		Z02_MIDPOINT : In sfixed;
		Z02_ENDPOINT : In sfixed;

		Z05_Y : Out sfixed(1 Downto -OUT_BW + 2) := (Others => '0');

		run : In Std_logic_vector(4 Downto 0)
	);

End bezier;

Architecture Behavioral Of bezier Is

	Constant dub0unsigned : unsigned(1 Downto 0) := "00";
	Constant dub0slv : Std_logic_vector(1 Downto 0) := "00";

	Attribute mark_debug : String;
	Attribute keep : String;

	Signal Z01_ONE_MINUS_T : sfixed(1 Downto -IN_BW + 2) := (Others => '0');
	Signal Z01_T : sfixed(1 Downto -IN_BW + 2) := (Others => '0');

	Signal Z02_A : sfixed(1 Downto -OUT_BW + 2) := (Others => '0');
	Signal Z02_B : sfixed(1 Downto -OUT_BW + 2) := (Others => '0');
	Signal Z02_C : sfixed(1 Downto -OUT_BW + 2) := (Others => '0');
	Signal Z03_D : sfixed(1 Downto -IN_BW + 2) := (Others => '0');
	Signal Z03_E : sfixed(1 Downto -IN_BW + 2) := (Others => '0');
	Signal Z03_F : sfixed(1 Downto -IN_BW + 2) := (Others => '0');
	Signal Z04_F : sfixed(1 Downto -OUT_BW + 2) := (Others => '0');
	Signal Z04_SUMA : sfixed(1 Downto -OUT_BW + 2) := (Others => '0');

	Signal Z02_A_slv : Std_logic_vector(OUT_BW - 1 Downto 0) := (Others => '0');
	Signal Z02_B_slv : Std_logic_vector(OUT_BW - 1 Downto 0) := (Others => '0');
	Signal Z02_C_slv : Std_logic_vector(OUT_BW - 1 Downto 0) := (Others => '0');

Begin
	Z02_A_slv <= to_slv(Z02_A);
	Z02_B_slv <= to_slv(Z02_B);
	Z02_C_slv <= to_slv(Z02_C);
	bezier_proc : Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
				-- Bezier curves:
				-- from wikipedia:
				-- B(t) = P0(1-t)^2 + 2*P1*(1-t)*t + P2*t^2
				-- assume P0x = 0, P1x = .5, P2x = 1 => B(t)x = t, then 
				-- B(t)y = StartY(1-t)^2 + 2*MidY*(1-t)*t + EndY*t^2
				-- or, B(t)y = StartY*A + 2*MidY*B + EndY*C
				-- ot, B(t)y = D + E + F

				--  calculate t and 1-t values
				-- increasing these values to 25-bit breaks the sfixed multiplier 
				If run(Z00) = '1' Then
					Z01_T <= resize(Abs(Z00_X), Z01_T);
					Z01_ONE_MINUS_T <= resize(1.0 - Abs(Z00_X), Z01_ONE_MINUS_T);
				End If;

				If run(Z01) = '1' Then
					Z02_A <= resize(Z01_ONE_MINUS_T * Z01_ONE_MINUS_T, Z02_A, fixed_wrap, fixed_truncate);
					Z02_B <= resize(Z01_ONE_MINUS_T * Z01_T, Z02_B, fixed_wrap, fixed_truncate);
					Z02_C <= resize(Z01_T * Z01_T, Z02_C, fixed_wrap, fixed_truncate);
				End If;

				If run(Z02) = '1' Then
					Z03_E <= resize(Z02_B * Z02_MIDPOINT * 2, Z03_E, fixed_wrap, fixed_truncate);
					-- use the set startpoint and endpoint
					Z03_F <= resize(Z02_C * Z02_ENDPOINT, Z03_F, fixed_wrap, fixed_truncate);
					Z03_D <= resize(Z02_A * Z02_STARTPOINT, Z03_D, fixed_wrap, fixed_truncate);
				End If;

				If run(Z03) = '1' Then
					Z04_SUMA <= resize(Z03_D + Z03_E, Z04_SUMA, fixed_saturate, fixed_truncate);
					Z04_F <= resize(Z03_F, Z04_F);
				End If;

				If run(Z04) = '1' Then
					Z05_Y <= resize(Z04_SUMA + Z04_F, Z04_SUMA, fixed_saturate, fixed_truncate);
				End If;
			End If;
		End If;
	End Process;
End Behavioral;