Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity chaser_mm Is
	Generic (
		LPF : Integer := 0;
		COUNT : Integer := 128;
		LOG2COUNT : Integer := 7
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		srun : In Std_logic_vector;
		Z03_en : In Std_logic;

		target_wr : In Std_logic;
		rate_wr : In Std_logic;
		exp_or_linear_wr : In Std_logic;
		mm_voiceaddr : In Std_logic_vector;
		mm_wrdata : In Std_logic_vector;
		mm_wrdata_rate : In Std_logic_vector;

		Z04_finished : Out Std_logic;

		Z00_rden : In Std_logic; -- should be 1 before data
		Z00_voiceaddr : In Std_logic_vector; -- should be 1 before data
		Z01_current : Out Std_logic_vector := (Others => '0')
	);
End chaser_mm;

Architecture arch_imp Of chaser_mm Is

	Signal Z01_srun : Std_logic_vector(srun'high - Z01 Downto 0);
	Signal mm_wrdata_processbw : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal selectionBit : Std_logic := '0';

	Signal Z03_moving : Std_logic_vector(0 Downto 0) := "0";
	Signal Z03_moving_last : Std_logic_vector(0 Downto 0) := "0";
	Signal Z01_target : Std_logic_vector(mm_wrdata'length - 1 Downto 0);
	Signal Z01_current_int : Std_logic_vector(mm_wrdata'length - 1 Downto 0) := (Others => '0');
	Signal Z01_rate : Std_logic_vector(mm_wrdata_rate'length - 1 Downto 0);
	Signal Z02_rate : sfixed(1 Downto -mm_wrdata_rate'length + 2);
	Signal Z04_current : sfixed(1 Downto -mm_wrdata'length + 2);
	Signal Z04_current_slv : Std_logic_vector(mm_wrdata'high Downto 0);

	Signal Z02_is_exponential : Std_logic_vector(0 Downto 0) := b"1";

	Signal Z01_voiceaddr : Std_logic_vector(Z00_voiceaddr'high Downto 0); -- should be 1 before data
	Signal Z02_voiceaddr : Std_logic_vector(Z00_voiceaddr'high Downto 0); -- should be 1 before data
	Signal Z03_voiceaddr : Std_logic_vector(Z00_voiceaddr'high Downto 0); -- should be 1 before data
	Signal Z04_voiceaddr : Std_logic_vector(Z00_voiceaddr'high Downto 0); -- should be 1 before data

Begin
	Z01_srun <= srun(srun'high Downto Z01);
	Z04_current_slv <= Std_logic_vector(Z04_current);
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then

				If srun(Z00) = '1' Then
					Z01_voiceaddr <= Z00_voiceaddr;
				End If;
				If srun(Z01) = '1' Then
					Z02_voiceaddr <= Z01_voiceaddr;
					Z02_rate <= sfixed(Z01_rate);
				End If;

				If srun(Z02) = '1' Then
					Z03_voiceaddr <= Z02_voiceaddr;
				End If;

				Z04_finished <= '0';
				If srun(Z03) = '1' Then
					Z04_voiceaddr <= Z03_voiceaddr;
					-- if the thing stopped moving, report it finished
					If Z03_moving(0) = '0' And Z03_moving_last(0) = '1' Then
						Z04_finished <= '1';
					End If;
				End If;

			End If;
		End If;
	End Process;
	Z01_current <= Z01_current_int;
	-- we need to periodically reduce these values 
	-- so they dont get stuck
	target : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceaddr,
			wrdata => mm_wrdata,
			wren => target_wr,
			rden => srun(Z00),
			rdaddr => Z00_voiceaddr,
			rddata => Z01_target
		);

	smoothed : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => Z04_voiceaddr,
			wrdata => Z04_current_slv,
			wren => srun(Z04),
			rden => srun(Z00),
			rdaddr => Z00_voiceaddr,
			rddata => Z01_current_int
		);

	moving : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => Z02_voiceaddr,
			wrdata => Z03_moving,
			wren => srun(Z02),
			rden => srun(Z02),
			rdaddr => Z02_voiceaddr,
			rddata => Z03_moving_last
		);

	rate : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceaddr,
			wrdata => mm_wrdata_rate,
			wren => rate_wr,
			rden => srun(Z00),
			rdaddr => Z00_voiceaddr,
			rddata => Z01_rate
		);
	-- sets exponent mode
	exp : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceaddr,
			wrdata => mm_wrdata(0 Downto 0),
			wren => exp_or_linear_wr,
			rden => srun(Z01),
			rdaddr => Z01_voiceaddr,
			rddata => Z02_is_exponential
		);
	chaser_i : Entity work.chaser
		--        Generic Map(
		--        )
		Port Map(
			clk => clk,
			rst => rst,
			srun => Z01_srun,
			Z02_en => Z03_en,
			Z01_is_exponential => Z02_is_exponential(0),

			Z00_target => Z01_target,
			Z00_current => Z01_current_int,
			Z00_voiceaddr => Z01_voiceaddr,
			Z01_rate => Z02_rate,
			Z03_moving => Z03_moving(0),
			Z03_current => Z04_current
		);

End arch_imp;