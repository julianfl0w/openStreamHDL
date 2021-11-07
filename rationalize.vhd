----------------------------------------------------------------------------------
-- Julian Loiacono 10/2017
--
-- Module Name: oscillators - Behavioral
--
-- Description: Generate an low-volume sine wave, at around 400 Hz
----------------------------------------------------------------------------------
Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;

Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;
Library work;
Use work.zconstants_pkg.All;

Entity rationalize Is
	Generic (
		ram_width18 : Integer := 18;
		ramaddr_width : Integer := 18
	);
	Port (
		clk : In Std_logic;

		ZN3_ADDR : In unsigned (RAMADDR_WIDTH - 1 Downto 0); -- Z01
		Z00_IRRATIONAL : In signed (ram_width18 - 1 Downto 0); -- Z01
		OSC_HARMONICITY_WREN : In Std_logic;
		MEM_IN : In Std_logic_vector(ram_width18 - 1 Downto 0);
		MEM_WRADDR : In Std_logic_vector(RAMADDR_WIDTH - 1 Downto 0);

		ZN2_RATIONAL : Out signed(ram_width18 - 1 Downto 0) := (Others => '0');

		initRam100 : In Std_logic;
		ram_rst100 : In Std_logic;
		OUTSAMPLEF_ALMOSTFULL : In Std_logic
	);

End rationalize;

Architecture Behavioral Of rationalize Is
	Component ram_controller_18k_18 Is
		Port (
			DO : Out Std_logic_vector (ram_width18 - 1 Downto 0);
			DI : In Std_logic_vector (ram_width18 - 1 Downto 0);
			RDADDR : In Std_logic_vector (ramaddr_width - 1 Downto 0);
			RDCLK : In Std_logic;
			RDEN : In Std_logic;
			REGCE : In Std_logic;
			RST : In Std_logic;
			WE : In Std_logic_vector (1 Downto 0);
			WRADDR : In Std_logic_vector (ramaddr_width - 1 Downto 0);
			WRCLK : In Std_logic;
			WREN : In Std_logic);
	End Component;

	Signal RAM_REGCE : Std_logic := '0';
	Signal RAM18_WE : Std_logic_vector (1 Downto 0) := (Others => '1');
	Signal RAM_RDEN : Std_logic := '0';

	Signal REPOSITION_WREN : Std_logic := '0';

	Attribute mark_debug : String;
	Signal ZN2_RATIONAL_oscdet_int : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');
	Signal Z00_OSC_HARMONICITY : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');
	Signal Z01_OSC_HARMONICITY : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');

	-- signals for nearest rational approx
	Constant decPlace : Natural := 14;
	Constant RATIONALADD_LOW : Natural := Z01;
	Constant RATIONALADD_HIGH : Natural := RAM_WIDTH18;

	Type PROPTYPE23 Is Array (1 To RAM_WIDTH18) Of signed(ram_width18 - 1 + 5 Downto 0);
	Type PROPTYPE18 Is Array (1 To RAM_WIDTH18) Of signed(ram_width18 - 1 Downto 0);
	Type PROPTYPE16 Is Array (1 To RAM_WIDTH18) Of unsigned(decPlace - 1 Downto 0);
	Type PROPTYPE6 Is Array (1 To RAM_WIDTH18) Of signed(6 - 1 Downto 0);
	Type PROPTYPENUM Is Array (1 To RAM_WIDTH18) Of signed(ram_width18 - 1 + 5 - decPlace Downto 0);
	Type PROPTYPE_OSCDET Is Array (ZN1 To Z21) Of signed(ram_width18 - 1 Downto 0);
	Signal SUM : PROPTYPE23 := (Others => (Others => '0'));
	Signal IRR : PROPTYPE18 := (Others => (Others => '0'));
	Signal OSC_HARMONICITY : PROPTYPE18 := (Others => (Others => '0'));
	Signal MAXFRAC : PROPTYPE16 := (Others => (Others => '0'));
	Signal DEN : PROPTYPE6 := (Others => "000001");
	Signal NUM : PROPTYPENUM := (Others => (Others => '0'));
	Signal ZN1_addr : unsigned(RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal ZN4_ADDR : unsigned(RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z19_addr : unsigned(RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z19_rational : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');
	Signal ZN3_RATIONAL : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');

	Type inversesArray Is Array(1 To RAM_WIDTH18) Of signed(RAM_WIDTH18 - 1 Downto 0);
	Constant inverse : inversesArray :=
		(
		to_signed((2 ** decPlace / 1), RAM_WIDTH18),
		to_signed((2 ** decPlace / 2), RAM_WIDTH18),
		to_signed((2 ** decPlace / 3), RAM_WIDTH18),
		to_signed((2 ** decPlace / 4), RAM_WIDTH18),
		to_signed((2 ** decPlace / 5), RAM_WIDTH18),
		to_signed((2 ** decPlace / 6), RAM_WIDTH18),
		to_signed((2 ** decPlace / 7), RAM_WIDTH18),
		to_signed((2 ** decPlace / 8), RAM_WIDTH18),
		to_signed((2 ** decPlace / 9), RAM_WIDTH18),
		to_signed((2 ** decPlace / 10), RAM_WIDTH18),
		to_signed((2 ** decPlace / 11), RAM_WIDTH18),
		to_signed((2 ** decPlace / 12), RAM_WIDTH18),
		to_signed((2 ** decPlace / 13), RAM_WIDTH18),
		to_signed((2 ** decPlace / 14), RAM_WIDTH18),
		to_signed((2 ** decPlace / 15), RAM_WIDTH18),
		to_signed((2 ** decPlace / 16), RAM_WIDTH18),
		to_signed((2 ** decPlace / 17), RAM_WIDTH18),
		to_signed((2 ** decPlace / 18), RAM_WIDTH18)
		);

	Signal Z00_timeDiv : Integer Range 0 To time_divisions - 1 := 0;
Begin
	Z00_timeDiv <= to_integer(ZN3_ADDR(1 Downto 0) + 3);

	i_harmonicity_ram : ram_controller_18k_18 Port Map(
		DO => Z00_OSC_HARMONICITY,
		DI => Std_logic_vector(MEM_IN),
		RDADDR => Std_logic_vector(ZN1_ADDR),
		RDCLK => clk,
		RDEN => RAM_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => Std_logic_vector(MEM_WRADDR),
		WRCLK => clk,
		WREN => OSC_HARMONICITY_WREN);

	i_reposition_ram : ram_controller_18k_18 Port Map(
		DO => ZN3_RATIONAL,
		DI => Std_logic_vector(Z19_RATIONAL),
		RDADDR => Std_logic_vector(ZN4_ADDR),
		RDCLK => clk,
		RDEN => RAM_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => Std_logic_vector(Z19_ADDR),
		WRCLK => clk,
		WREN => REPOSITION_WREN);

	phase_proc : Process (clk)
	Begin
		If rising_edge(clk) Then

			REPOSITION_WREN <= '0';

			If initRam100 = '0' And OUTSAMPLEF_ALMOSTFULL = '0' Then
				ZN2_RATIONAL <= signed(ZN3_RATIONAL);

				Z01_OSC_HARMONICITY <= Z00_OSC_HARMONICITY;
				ZN1_addr <= ZN3_addr - Z01;
				ZN4_ADDR <= ZN1_addr + 4;
				Z19_addr <= ZN1_addr - Z19;

				-- rationalize!
				-- determine the residual fraction for irrational*1, irrational *2, ... , irrational*18
				-- the minimum of these indicates the numerator and denominator of rational approximation

				-- the irrational number is propagated
				IRR(1) <= Z00_IRRATIONAL;
				-- sum is increased by IRR every clock, and starts at IRR
				SUM(1) <= resize(Z00_IRRATIONAL, SUM(4)'length);
				-- MAXFRAC is the absolute distance from 0
				--MAXFRAC(address, Z04) <= abs(signed(Z03_OSC_DETUNE(decPlace-1 downto 0)));
				-- MAXFRAC is the distance above 0
				-- but only if harmon(0) is indicated
				If Z00_OSC_HARMONICITY(0) = '1' Then
					MAXFRAC(1) <= unsigned(Z00_IRRATIONAL(decPlace - 1 Downto 0));
				Else
					--MAXFRAC(1) <= (others=>'1');
					-- start MAXFRAC at 0 because this is a ceining function
					MAXFRAC(1) <= (Others => '0');
				End If;

				-- the denominator starts with 1
				DEN(1) <= to_signed(1, DEN(1)'length);
				-- the numerator is the integer part of the irrational number
				NUM(1) <= resize(Z00_IRRATIONAL(ram_width18 - 1 Downto decPlace), NUM(1)'length);

				OSC_HARMONICITY(1) <= signed(Z00_OSC_HARMONICITY);

				proploop :
				For propnum In 2 To RAM_WIDTH18 Loop
					IRR(propnum) <= IRR(propnum - 1);
					SUM(propnum) <= SUM(propnum - 1) + IRR(propnum - 1);
					OSC_HARMONICITY(propnum) <= OSC_HARMONICITY(propnum - 1);

					--this conditional finds nearest neighbor
					--if  abs(signed(SUM(propnum-1)(decPlace-1 downto 0))) < MAXFRAC(propnum-1)
					--but we want lowest neighbor
					--if  unsigned(SUM(propnum-1)(decPlace-1 downto 0)) <= MAXFRAC(propnum-1)
					-- but we want highest neighbor
					If unsigned(SUM(propnum - 1)(decPlace - 1 Downto 0)) >= MAXFRAC(propnum - 1)
						And OSC_HARMONICITY(propnum - 1)(propnum - 2) = '1' Then
						--MAXFRAC(propnum) <= abs(signed(SUM(propnum-1)(decPlace-1 downto 0)));
						MAXFRAC(propnum) <= unsigned(SUM(propnum - 1)(decPlace - 1 Downto 0));
						DEN(propnum) <= to_signed(propnum - 1, DEN(RATIONALADD_LOW)'length);
						-- because this is a ceiling type, add 1 to numerator here
						NUM(propnum) <= SUM(propnum - 1)(ram_width18 - 1 + 5 Downto decPlace) + 1;
					Else
						--otherwise, propagate
						MAXFRAC(propnum) <= MAXFRAC(propnum - 1);
						DEN(propnum) <= DEN(propnum - 1);
						NUM(propnum) <= NUM(propnum - 1);
					End If;
				End Loop;

				-- output irrational if no harmonicity set
				If OSC_HARMONICITY(Z18) = 0 Then
					Z19_rational <= Std_logic_vector(IRR(Z18));
				Else
					Z19_rational <= Std_logic_vector(MULT(NUM(RAM_WIDTH18),
						inverse(to_integer(den(RAM_WIDTH18))), RAM_WIDTH18, 4 + 5));
				End If;
				REPOSITION_WREN <= '1';

			End If;
		End If;
	End Process;

	RAM_RDEN <= Not OUTSAMPLEF_ALMOSTFULL;

End Behavioral;