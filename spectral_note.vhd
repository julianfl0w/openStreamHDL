-- Turn parameters into a sine-bank amplitude array!

-- the basic parameters of a note:
-- envelope
-- Harmonic width
-- F0 filter     (bidirectional)
-- Global filter (unidirectional)
-- F0 
-- Lowest harmonic
-- Highest harmonic

Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

Entity spectral_note Is
	Generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		PHASEPRECISION : Integer := 32;
		CHANNEL_COUNT : Integer := 2;
		NOTE_COUNT : Integer := 1024;
		CTRL_COUNT : Integer := 4;
		MAX_HARMONICS : Integer := 32;
		TOTAL_SINES_ADDRBW : Integer := 14;
		BANKCOUNT : Integer := 12;
		BANKCOUNT_ADDRBW : Integer := 4;
		SINESPERBANK : Integer := 1024;
		SINESPERBANK_ADDRBW : Integer := 10;
		PROCESS_BW : Integer := 18;
		CYCLE_BW : Integer := 3;
		VOLUMEPRECISION : Integer := 16
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

		Z22_amparray_wren      : Out Std_logic_vector(BANKCOUNT - 1 Downto 0) := (Others => '0');
		Z22_amparray_wraddr    : Out Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
		Z22_amparray_wrdata    : Out Std_logic_vector(VOLUMEPRECISION - 1 Downto 0) := (Others => '0');
		Z22_amparray_CURRCYCLE : Out Std_logic_vector(CYCLE_BW - 1 Downto 0) := (Others => '0');

		hwidth_wr : In Std_logic := '0';
		hwidth_inv_wr : In Std_logic := '0';
		basenote_wr : In Std_logic := '0';
		harmonic_en_wr : In Std_logic := '0';
		fmfactor_wr : In Std_logic := '0';
		fmdepth_wr : In Std_logic := '0';
		centsinc_wr : In Std_logic := '0';

		envelope_env_speed_wr : In Std_logic;
		envelope_env_bezier_MIDnENDpoint_wr : In Std_logic;

		pbend_env_speed_wr : In Std_logic;
		pbend_env_bezier_MIDnENDpoint_wr : In Std_logic;

		hwidth_env_speed_wr : In Std_logic;
		hwidth_env_3EndPoints_wr : In Std_logic;

		nfilter_env_speed_wr : In Std_logic;
		nfilter_env_bezier_3EndPoints_wr : In Std_logic;

		gfilter_env_speed_wr : In Std_logic;
		gfilter_env_bezier_3EndPoints_wr : In Std_logic;

		IRQueue_out_ready : In Std_logic;
		IRQueue_out_valid : Out Std_logic;
		IRQueue_out_data : Out Std_logic_vector(15 Downto 0);

		mm_wraddr : In Std_logic_vector;
		mm_wrdata : In Std_logic_vector

	);
End spectral_note;

Architecture arch_imp Of spectral_note Is

	Signal Z22_amparray_wren_int : Std_logic_vector(BANKCOUNT - 1 Downto 0) := (Others => '0');
	Signal Z22_lastupdated_wren  : std_logic := '0';
	Signal Z22_amparray_wraddr_int : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');

	Type HARMONIC_DISTANCE_CENTS_TYPE Is Array (0 To MAX_HARMONICS - 1) Of signed(TOTAL_SINES_ADDRBW - 1 Downto 0);
	Constant Harmonic_Distance_Cents_EqualTemp : HARMONIC_DISTANCE_CENTS_TYPE :=
		(
		--http://www.sengpielaudio.com/calculator-centsratio.htm

		to_signed(-SINESPERBANK * log2(16), TOTAL_SINES_ADDRBW), -- 1/16x
		to_signed(-SINESPERBANK * log2(15), TOTAL_SINES_ADDRBW), -- 1/15x
		to_signed(-SINESPERBANK * log2(14), TOTAL_SINES_ADDRBW), -- 1/14x
		to_signed(-SINESPERBANK * log2(13), TOTAL_SINES_ADDRBW), -- 1/13x
		to_signed(-SINESPERBANK * log2(12), TOTAL_SINES_ADDRBW), -- 1/12x
		to_signed(-SINESPERBANK * log2(11), TOTAL_SINES_ADDRBW), -- 1/11x
		to_signed(-SINESPERBANK * log2(10), TOTAL_SINES_ADDRBW), -- 1/10x
		to_signed(-SINESPERBANK * log2( 9), TOTAL_SINES_ADDRBW), -- 1/9x
		to_signed(-SINESPERBANK * log2( 8), TOTAL_SINES_ADDRBW), -- 1/8x
		to_signed(-SINESPERBANK * log2( 7), TOTAL_SINES_ADDRBW), -- 1/7x
		to_signed(-SINESPERBANK * log2( 6), TOTAL_SINES_ADDRBW), -- 1/6x
		to_signed(-SINESPERBANK * log2( 5), TOTAL_SINES_ADDRBW), -- 1/5x
		to_signed(-SINESPERBANK * log2( 4), TOTAL_SINES_ADDRBW), -- 1/4x
		to_signed(-SINESPERBANK * log2( 3), TOTAL_SINES_ADDRBW), -- 1/3x
		to_signed(-SINESPERBANK * log2( 2), TOTAL_SINES_ADDRBW), -- 1/2x
		to_signed( 0   , TOTAL_SINES_ADDRBW), --  1x
		to_signed( SINESPERBANK * log2( 2), TOTAL_SINES_ADDRBW), --  2x
		to_signed( SINESPERBANK * log2( 3), TOTAL_SINES_ADDRBW), --  3x
		to_signed( SINESPERBANK * log2( 4), TOTAL_SINES_ADDRBW), --  4x
		to_signed( SINESPERBANK * log2( 5), TOTAL_SINES_ADDRBW), --  5x
		to_signed( SINESPERBANK * log2( 6), TOTAL_SINES_ADDRBW), --  6x
		to_signed( SINESPERBANK * log2( 7), TOTAL_SINES_ADDRBW), --  7x
		to_signed( SINESPERBANK * log2( 8), TOTAL_SINES_ADDRBW), --  8x
		to_signed( SINESPERBANK * log2( 9), TOTAL_SINES_ADDRBW), --  9x
		to_signed( SINESPERBANK * log2(10), TOTAL_SINES_ADDRBW), -- 10x
		to_signed( SINESPERBANK * log2(11), TOTAL_SINES_ADDRBW), -- 11x
		to_signed( SINESPERBANK * log2(12), TOTAL_SINES_ADDRBW), -- 12x
		to_signed( SINESPERBANK * log2(13), TOTAL_SINES_ADDRBW), -- 13x
		to_signed( SINESPERBANK * log2(14), TOTAL_SINES_ADDRBW), -- 14x
		to_signed( SINESPERBANK * log2(15), TOTAL_SINES_ADDRBW), -- 15x
		to_signed( SINESPERBANK * log2(16), TOTAL_SINES_ADDRBW) -- 16x

		);
	Constant NOTEADDR_BW : Integer := Integer(round(log2(real(NOTE_COUNT))));

	Signal mm_wraddr_note : Std_logic_vector(NOTEADDR_BW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_processbw : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_totalsinesbw : Std_logic_vector(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_sinesperoctbw : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');

	Signal run : Std_logic_vector(Z21 Downto Z00) := (Others => '0');
	Signal Z11_run : Std_logic_vector(5 Downto 0) := (Others => '0');
	Signal valid_override : Std_logic_vector(run'high Downto run'low) := (Others => '0');

	Constant SINETOCTRL : real := 1.0 / real(SINESPERBANK * BANKCOUNT);

	Signal currentIRQueueSource : Integer := 0;
	Signal pbend_env_finished_ready : Std_logic := '0';
	Signal pbend_env_finished_valid : Std_logic := '0';
	Signal pbend_env_finished_addr : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0)  := (Others => '0');

	Signal hwidth_env_finished_ready : Std_logic := '0';
	Signal hwidth_env_finished_valid : Std_logic := '0';
	Signal hwidth_env_finished_addr : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0) := (Others => '0');

	Signal nfilter_env_finished_ready : Std_logic := '0';
	Signal nfilter_env_finished_valid : Std_logic := '0';
	Signal nfilter_env_finished_addr : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0) := (Others => '0');

	Signal gfilter_env_finished_ready : Std_logic := '0';
	Signal gfilter_env_finished_valid : Std_logic := '0';
	Signal gfilter_env_finished_addr : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0) := (Others => '0');

	Signal envelope_env_finished_ready : Std_logic := '0';
	Signal envelope_env_finished_valid : Std_logic := '0';
	Signal envelope_env_finished_addr : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0) := (Others => '0');

	Signal IRQueue_in_ready : Std_logic;
	Signal IRQueue_in_valid : Std_logic := '0';
	Signal IRQueue_in_data : Std_logic_vector(15 Downto 0) := (Others => '0');

	Signal Z17_hwidth_effect : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z16_nfilter_effect : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z17_gfilter_effect : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal Z14_pbend_effect : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z14_pbend_effect_slv : std_logic_vector(TOTAL_SINES_ADDRBW-1 downto 0) := (Others => '0');
	Signal Z15_pbend_effect : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z16_pbend_fm : sfixed(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z17_bent_fm_index : sfixed(SINESPERBANK_ADDRBW + BANKCOUNT_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z18_bent_fm_bank_index : Std_logic_vector(SINESPERBANK_ADDRBW + BANKCOUNT_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z19_bent_bank : Integer := 0;
	Signal Z20_bent_bank : Integer := 0;
	Signal Z21_bent_bank : Integer := 0;
	Signal Z19_bent_index : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z20_bent_index : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z21_bent_index : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z14_envelope_effect : sfixed(1 Downto -PROCESS_BW + 2) := to_sfixed(1, 1, -PROCESS_BW + 2);
	Signal Z15_iProd0 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z16_iProd0 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z17_iProd0 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z18_iProd0 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z18_iProd1 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z18_iProd0_slv : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z18_iProd1_slv : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z19_iProd1 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z20_iProd1 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z21_iProd1 : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z22_extant_amp : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z22_extant_amp_wraddr : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z22_extant_amp_wren : Std_logic_vector(BANKCOUNT - 1 Downto 0) := (Others => '0');

	Signal Z17_FM_DEPTH : Std_logic_vector(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z18_FM_DEPTH : sfixed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z17_FM_Mod : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z14_FM_Mod : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z15_FM_Mod : sfixed(TOTAL_SINES_ADDRBW Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z16_adjustedosc : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal Z21_extant_ampsf : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal Z01_hwidth : Std_logic_vector(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z01_F0index : Std_logic_vector(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');

	Signal Z01_harmonic_en : Std_logic_vector(mm_wrdata'high Downto 0) := (Others => '0');

	Signal Z01_indexInHarmonic : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z01_centsinc : Std_logic_vector(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z02_indexInHarmonic : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z02_H0SineIndex : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z02_Hwidth_inv  : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z03_Hwidthinvsf : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z02_Cent        : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z02_F0index     : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z03_CentralSineIndex : signed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z03_CentralSineIndexsf : sfixed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z01_current_harmonic : Integer := 0;
	Signal Z02_current_harmonic : Integer := 0;

    attribute mark_debug : string;
    attribute mark_debug of Z02_F0index   : signal is "true";
    attribute mark_debug of Z18_iProd0_slv: signal is "true";
    attribute mark_debug of Z18_iProd1_slv: signal is "true";

	Signal Z03_SineIndexsf     : sfixed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z04_SineIndexNormal : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z05_SineIndexNormal : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z10_SineIndexsf     : sfixed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z11_SineIndexsf     : sfixed(TOTAL_SINES_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal Z12_SineIndexNormal : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z16_SineIndexsf     : sfixed(TOTAL_SINES_ADDRBW Downto 0) := (Others => '0');
	Signal Z09_freq_hz         : sfixed (PROCESS_BW Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z10_Osc             : sfixed(0 Downto -PROCESS_BW + 1) := (Others => '0');
	Signal Z09_FM_Factor       : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z10_FM_Factor_sf    : sfixed(PROCESS_BW/2 Downto -PROCESS_BW/2 + 1) := (Others => '0');
	Signal Z11_FM_Mod_Phase    : sfixed(0 Downto -PROCESS_BW + 1) := (Others => '0');
	Signal Z11_FM_Mod_Phase_signed : signed(PROCESS_BW - 1 Downto 0) := (Others => '0');

	Type noterelsineindex Is Array(Z03 To Z14) Of sfixed(0 Downto -TOTAL_SINES_ADDRBW);
	Signal NoteRelSineIndexsf : noterelsineindex := (Others => (Others => '0'));
	Signal Z11_NoteRelSineIndexsf : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal Z03_Cent : sfixed(TOTAL_SINES_ADDRBW + 2 - 1 Downto 0) := (Others => '0');
	Type Centarray Is Array(Z04 To Z12) Of sfixed(1 Downto -TOTAL_SINES_ADDRBW + 2);
	Signal Centsf : Centarray := (Others => (Others => '0'));

	Signal Z00_NoteIndex : Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0) := (Others => '0');
	Type addrtype Is Array(Z01 To Z22) Of Std_logic_vector(Integer(round(log2(real(NOTE_COUNT)))) - 1 Downto 0);
	Signal NoteIndex : addrtype := (Others => (Others => '0'));

	Type cycletype Is Array(Z01 To Z22) Of unsigned(CYCLE_BW - 1 Downto 0);
	Signal CURRCYCLE : cycletype := (Others => (Others => '0'));

	Type sineaddrtype Is Array(Z00 To Z30) Of signed(TOTAL_SINES_ADDRBW - 1 Downto 0);
	Signal SineIndex : sineaddrtype := (Others => (Others => '0'));

	Type extantdatatype Is Array(0 To BANKCOUNT - 1) Of Std_logic_vector(PROCESS_BW - 1 Downto 0);
	Signal Z20_extant_amp : extantdatatype := (Others => (Others => '0'));
	Type cycledatatype Is Array(0 To BANKCOUNT - 1) Of unsigned(CYCLE_BW - 1 Downto 0);
	Signal Z20_LAST_UPDATED : Std_logic_vector(bankCOUNT*CYCLE_BW-1 downto 0) := (Others => '0');
	Signal Z21_LAST_UPDATED : cycledatatype := (Others =>(Others => '0'));
	Signal Z22_LAST_UPDATED : std_logic_vector(bankCOUNT*CYCLE_BW-1 downto 0) := (Others => '0');

	Signal osc_1Hz : unsigned(27 Downto 0) := (Others => '0');
	Signal Z09_osc_1Hz_sf : sfixed(0 Downto -27) := (Others => '0');

Begin
	-- TODO: 1024-step arbitrary filter
    Z18_iProd0_slv <= Std_logic_vector(Z18_iProd0);
    Z18_iProd1_slv <= Std_logic_vector(Z18_iProd1);

	mm_wrdata_processbw <= mm_wrdata(PROCESS_BW - 1 Downto 0);
	mm_wrdata_totalsinesbw <= mm_wrdata(TOTAL_SINES_ADDRBW - 1 Downto 0);
	mm_wrdata_sinesperoctbw <= mm_wrdata(SINESPERBANK_ADDRBW - 1 Downto 0);
	mm_wraddr_note <= mm_wraddr(mm_wraddr'high Downto mm_wraddr'length - Integer(round(log2(real(NOTE_COUNT)))));

	Z22_amparray_wren <= Z22_amparray_wren_int;
	Z22_amparray_wraddr <= Z22_amparray_wraddr_int;

	-- I/O Connections assignments
	flow_i : Entity work.flow_override
		Port Map(
			clk => clk,
			rst => rst,

			in_ready => Open,
			in_valid => '1',
			out_ready => '1',
			out_valid => Open,

			valid_override => valid_override,
			run => run
		);

    lastupdatedArray : Entity work.simple_dual_one_clock
        Generic Map(
            DATA_WIDTH => bankCOUNT*CYCLE_BW,
            ADDR_WIDTH => SINESPERBANK_ADDRBW
        )
        Port Map(
            clk => clk,
            wea => '1',
            wren   => Z22_lastupdated_wren,
            wraddr => Z22_amparray_wraddr_int,
            wrdata => Z22_LAST_UPDATED,
            rden => run (Z19),
            rdaddr => Z19_bent_index,
            rddata => Z20_LAST_UPDATED
        );
        
	-- in the future, you may want to solve each bank independantly
	banks :
	For bank In 0 To bankCOUNT - 1 Generate
		-- Keep the amp array here, for updating before indicating it's valid
		extantZ22_amparray : Entity work.simple_dual_one_clock
			Generic Map(
				DATA_WIDTH => PROCESS_BW,
				ADDR_WIDTH => SINESPERBANK_ADDRBW
			)
			Port Map(
				clk => clk,
				wea => '1',
				wren => Z22_extant_amp_wren(bank),
				wraddr => Z22_extant_amp_wraddr,
				wrdata => Z22_extant_amp,
				rden => run(Z19),
				rdaddr => Z19_bent_index,
				rddata => Z20_extant_amp(bank)
			);
			
	End Generate;

	-- Begin Time-static Note Parameters
	-- lowest harmonic :
	harmonicEnable : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => mm_wrdata'length,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => harmonic_en_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata,
			rden => run(Z00),
			rdaddr => Z00_NoteIndex,
			rddata => Z01_harmonic_en
		);

	-- harmonic width in cents:
	-- IE. the spectral width of each harmonic
	harmonicWidthInCents : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => TOTAL_SINES_ADDRBW,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => hwidth_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata_totalsinesbw,
			rdaddr => Z00_NoteIndex,
			rden => run(Z00),
			rddata => Z01_hwidth
		);

	-- F0 index in cents:
	fundamentalIndex : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => TOTAL_SINES_ADDRBW,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => basenote_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata_totalsinesbw,
			rden => run(Z00),
			rdaddr => Z00_NoteIndex,
			rddata => Z01_F0index
		);

	hwidth_inv : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => PROCESS_BW,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => hwidth_inv_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata_processbw,
			rden => run(Z01),
			rdaddr => NoteIndex(Z01),
			rddata => Z02_HWIDTH_INV
		);

--	fm_depth : Entity work.simple_dual_one_clock
--		Generic Map(
--			DATA_WIDTH => TOTAL_SINES_ADDRBW,
--			ADDR_WIDTH => NOTEADDR_BW
--		)
--		Port Map(
--			clk => clk,
--			wren => fmdepth_wr,
--			wea => '1',
--			wraddr => mm_wraddr_note,
--			wrdata => mm_wrdata_totalsinesbw,
--			rden => run(Z16),
--			rdaddr => NoteIndex(Z16),
--			rddata => Z17_FM_DEPTH
--		);

	cents_increment : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => TOTAL_SINES_ADDRBW,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => centsinc_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata_totalsinesbw,
			rden => run(Z00),
			rdaddr => Z00_NoteIndex,
			rddata => Z01_centsinc
		);
--	fm_factor : Entity work.simple_dual_one_clock
--		Generic Map(
--			DATA_WIDTH => PROCESS_BW,
--			ADDR_WIDTH => NOTEADDR_BW
--		)
--		Port Map(
--			clk => clk,
--			wren => fmfactor_wr,
--			wea => '1',
--			wraddr => mm_wraddr_note,
--			wrdata => mm_wrdata_processbw,
--			rden => run(Z08),
--			rdaddr => NoteIndex(Z08),
--			rddata => Z09_FM_Factor
--		);

	-- Begin Time-Variant effects
	-- Harmonic Width Path
	harmonic_width : Entity work.effect2d
		Generic Map(
			NOTE_COUNT => NOTE_COUNT
		)
		Port Map(
			clk => clk,
			rst => rst,
			Z00_addr => NoteIndex(Z08),
			Z03_addr => NoteIndex(Z11),
			Z06_addr => NoteIndex(Z14),

			bt_target_endpoints_wr => hwidth_env_3EndPoints_wr,
			env_speed_wr => hwidth_env_speed_wr,

			env_finished_ready => hwidth_env_finished_ready,
			env_finished_valid => hwidth_env_finished_valid,
			env_finished_addr => hwidth_env_finished_addr,

			Z04_Ctrl_2ndStage => Centsf(Z12),
			Z09_effect_out => Z17_hwidth_effect,

			mm_wraddr => mm_wraddr_note,
			mm_wrdata => mm_wrdata,

			run => run
		);
	-- note filter path
	nfilter : Entity work.effect2d
		Generic Map(
			NOTE_COUNT => NOTE_COUNT
		)
		Port Map(
			clk => clk,
			rst => rst,
			Z00_addr => NoteIndex(Z07),
			Z03_addr => NoteIndex(Z10),
			Z06_addr => NoteIndex(Z13),

			env_speed_wr => nfilter_env_speed_wr,
			bt_target_endpoints_wr => nfilter_env_bezier_3EndPoints_wr,

			env_finished_ready => nfilter_env_finished_ready,
			env_finished_valid => nfilter_env_finished_valid,
			env_finished_addr => nfilter_env_finished_addr,

			Z04_Ctrl_2ndStage => Z11_NoteRelSineIndexsf,
			Z09_effect_out => Z16_nfilter_effect,

			mm_wraddr => mm_wraddr_note,
			mm_wrdata => mm_wrdata,

			run => run
		);

	-- global filter path
	gfilter : Entity work.effect2d
		Generic Map(
			NOTE_COUNT => NOTE_COUNT
		)
		Port Map(
			clk => clk,
			rst => rst,
			Z00_addr => NoteIndex(Z08),
			Z03_addr => NoteIndex(Z11),
			Z06_addr => NoteIndex(Z14),

			bt_target_endpoints_wr => gfilter_env_bezier_3EndPoints_wr,
			env_speed_wr => gfilter_env_speed_wr,

			env_finished_ready => gfilter_env_finished_ready,
			env_finished_valid => gfilter_env_finished_valid,
			env_finished_addr => gfilter_env_finished_addr,

			Z04_Ctrl_2ndStage => Z12_SineIndexNormal,
			Z09_effect_out => Z17_gfilter_effect,

			mm_wraddr => mm_wraddr_note,
			mm_wrdata => mm_wrdata,

			run => run
		);

	pbend : Entity work.simple_dual_one_clock
		Generic Map(
			DATA_WIDTH => TOTAL_SINES_ADDRBW,
			ADDR_WIDTH => NOTEADDR_BW
		)
		Port Map(
			clk => clk,
			wren => pbend_env_bezier_MIDnENDpoint_wr,
			wea => '1',
			wraddr => mm_wraddr_note,
			wrdata => mm_wrdata_totalsinesbw,
			rden   => run(Z13),
			rdaddr => NoteIndex(Z13),
			rddata => Z14_pbend_effect_slv
		);
	-- pitch bend effect
	-- pitchbend : Entity work.effect1d
	-- 	Generic Map(
	-- 		NOTE_COUNT => NOTE_COUNT
	-- 	)
	-- 	Port Map(
	-- 		clk => clk,
	-- 		rst => rst,
	-- 		Z00_addr => NoteIndex(Z08),
	-- 		Z06_addr => NoteIndex(Z14),
    -- 
	-- 		env_speed_wr => pbend_env_speed_wr,
	-- 		env_bezier_MIDnENDpoint_wr => pbend_env_bezier_MIDnENDpoint_wr,
    -- 
	-- 		env_finished_ready => pbend_env_finished_ready,
	-- 		env_finished_valid => pbend_env_finished_valid,
	-- 		env_finished_addr => pbend_env_finished_addr,
    -- 
	-- 		Z06_env => Z14_pbend_effect,
    -- 
	-- 		mm_wraddr => mm_wraddr_note,
	-- 		mm_wrdata => mm_wrdata,
    -- 
	-- 		run => run
	-- 	);

	--envelope effect
--	envelope_i : Entity work.effect1d
--		Generic Map(
--			NOTE_COUNT => NOTE_COUNT
--		)
--		Port Map(
--			clk => clk,
--			rst => rst,
--			Z00_addr => NoteIndex(Z08),
--			Z06_addr => NoteIndex(Z14),
    
--			env_speed_wr => envelope_env_speed_wr,
--			env_bezier_MIDnENDpoint_wr => envelope_env_bezier_MIDnENDpoint_wr,
    
--			env_finished_ready => envelope_env_finished_ready,
--			env_finished_valid => envelope_env_finished_valid,
--			env_finished_addr => envelope_env_finished_addr,
    
--			Z06_env => Z14_envelope_effect,
    
--			mm_wraddr => mm_wraddr_note,
--			mm_wrdata => mm_wrdata,
    
--			run => run
--		);

	-- calculate the appropriate modulator for FM 
--	power_i : Entity work.power
--		Generic Map(
--			PROCESS_BW => 18,
--			Z00_NATLOG_OF_Base => 0.00057762265 -- ln(2^(1/1200))
--		)
--		Port Map(
--			clk => clk,
--			rst => rst,

--			run => run,
--			Z00_Exponent => Z03_CentralSineIndexsf,
--			Z06_rslt => Z09_freq_hz
--		);

--	Z11_FM_Mod_Phase_signed <= signed(Z11_FM_Mod_Phase);
--	Z11_run <= run(Z16 Downto Z11);
--	i_sine_lookup : Entity work.sine_lookup
--		Generic Map(
--			OUT_BW => PROCESS_BW,
--			PHASE_WIDTH => PROCESS_BW
--		)
--		Port Map(
--			clk => clk,
--			rst => rst,
--			Z00_PHASE_in => Z11_FM_Mod_Phase_signed,
--			Z06_SINE_out => Z17_FM_Mod,
--			run => Z11_run
--		);

	-- in the future, you may want to solve each bank independantly
	banks2 :
	For bank In 0 To bankCOUNT - 1 Generate
		bancproc:
        Process (clk)
        Begin
		If rising_edge(clk) Then
			if run(Z20) = '1' then
                Z21_LAST_UPDATED(bank) <= unsigned(Z20_LAST_UPDATED((bank+1)*CYCLE_BW-1 downto bank*CYCLE_BW));
            end if;
			if run(Z21) = '1' then
			    if bank = Z21_bent_bank then 
                    Z22_LAST_UPDATED((bank+1)*CYCLE_BW-1 downto bank*CYCLE_BW) <= std_logic_vector(CurrCycle(Z21));
                else
                    Z22_LAST_UPDATED((bank+1)*CYCLE_BW-1 downto bank*CYCLE_BW) <= std_logic_vector(Z21_LAST_UPDATED(bank));
                end if;
		    end if;
		end if;
		end process;

	End Generate;

	-- there are 2 approaches to summing up a number of notes:
	-- 1) Iterate through the frequency indices (20-20k, 12000 indices), then loop through every note
	-- 2) Loop through every note, and only the harmonics that apply to each

	-- furthermore, there are 2 paradigms for sine interpretation:
	-- 1) calculate the sine for each harmonic + note params, and add its contribution to an incrementer
	-- this can avoid having to keep the entire sine envelope array in memory, but is infeasible on 35T device
	-- 2) add the contribution values to an incrementer <- this makes sense

	-- we will do 2, 2
	-- Z00_NoteIndex <= Z00_NoteIndexNext when ((Z01_current_harmonic + 1) >= signed(Z01_hhigh) and  (Z01_indexInHarmonic + 1 ) >= signed(Z01_hwidth)*2 ) or to_integer(unsigned(Z01_F0index)) >= 12000 else std_logic_vector(unsigned(Z00_NoteIndexNext)-1);
	-- sum process
	sum_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			-- maintain a 1Hz signal
			osc_1Hz <= osc_1Hz + 1;
			If osc_1Hz = 100000000 Then
				osc_1Hz <= (Others => '0');
			End If;

			If rst = '0' Then
				-- idk
				voloop :
				For i In valid_override'low + 1 To valid_override'high Loop
					If run(i - 1) = '1' Then
						valid_override(i) <= '0';
					End If;
				End Loop;

				If run(Z00) = '1' Then
					NoteIndex(Z01) <= Z00_NoteIndex;
					-- if note index wrapped, increase cycle
					If Z00_NoteIndex < NoteIndex(Z01) Then
						CURRCYCLE(Z01) <= CURRCYCLE(Z01) + 1;
					End If;
				End If;

				If run(Z01) = '1' Then

					-- iterate over harmonics in note
					Z02_H0SineIndex <= signed(Z01_F0index) + Z01_indexInHarmonic - signed(Z01_hwidth);
					Z02_Cent <= Z01_indexInHarmonic - signed(Z01_hwidth) + 1;
					Z02_F0index <= signed(Z01_F0index);

					-- always increase index in harmonic 
					Z01_indexInHarmonic <= Z01_indexInHarmonic + signed(Z01_centsinc);

					-- this step not valid unless harmonic is enabled
					If Z01_harmonic_en(Z01_current_harmonic) = '0' Then
						valid_override(Z02) <= '1';
					End If;

					-- if this harmonic is completed
					If Z01_indexInHarmonic >= signed(Z01_hwidth) * 2 Then
						Z01_current_harmonic <= Z01_current_harmonic + 1;
						Z01_indexInHarmonic <= to_signed(0, Z01_indexInHarmonic'length);
						valid_override(Z02) <= '1';

						-- if weve completed the note, on to the next one
						If Z01_current_harmonic >= MAX_HARMONICS - 1 Or unsigned(Z01_harmonic_en) = 0 Then
							Z01_current_harmonic <= 0;

							-- late adjustment: invalidate all steps since
							Z00_NoteIndex <= Std_logic_vector(unsigned(Z00_NoteIndex) + 1);
							--valid_override(Z00) <= '1';
							valid_override(Z01) <= '1';
						End If;
					End If;

					Z02_current_harmonic <= Z01_current_harmonic;
					Z02_indexInHarmonic <= Z01_indexInHarmonic;
				End If;

				If run(Z02) = '1' Then
					Z03_Cent(Z03_Cent'high - 2 Downto Z03_Cent'low) <= sfixed(Z02_Cent);
					SineIndex(Z03) <= signed(Harmonic_Distance_Cents_EqualTemp(Z02_current_harmonic) + Z02_H0SineIndex);
					Z03_SineIndexsf <= sfixed(Harmonic_Distance_Cents_EqualTemp(Z02_current_harmonic) + Z02_H0SineIndex);
					-- get the note-relative index as well
					NoteRelSineIndexsf(Z03)(-1 Downto -TOTAL_SINES_ADDRBW) <= sfixed(Harmonic_Distance_Cents_EqualTemp(Z02_current_harmonic)
					+ Z02_H0SineIndex);

					Z03_CentralSineIndex <= Z02_F0index + Harmonic_Distance_Cents_EqualTemp(Z02_current_harmonic);
					Z03_CentralSineIndexsf <= sfixed(Z02_F0index + Harmonic_Distance_Cents_EqualTemp(Z02_current_harmonic));

					Z03_Hwidthinvsf <= sfixed(Z02_HWIDTH_INV);
				End If;

				If run(Z03) = '1' Then
					Z04_SineIndexNormal <= resize(Z03_SineIndexsf * to_sfixed(SINETOCTRL, -10, -TOTAL_SINES_ADDRBW - 10), Z04_SineIndexNormal, fixed_wrap, fixed_truncate);
					Centsf(Z04) <= resize(Z03_Cent * Z03_Hwidthinvsf, Centsf(Z04), fixed_wrap, fixed_truncate);
					-- sine index might still be invalid. just ignore if so
					If signed(SineIndex(Z03)) >= 12000 Or SineIndex(Z03) < 0 Then
						valid_override(Z04) <= '1';
					Else
						valid_override(Z04) <= '0';
					End If;
				End If;

				If run(Z04) = '1' Then
					Centsf(Z05) <= resize(Abs(Centsf(Z04)), Centsf(Z05), fixed_wrap, fixed_truncate);
					Z05_SineIndexNormal <= Z04_SineIndexNormal;
				End If;

				If run(Z06) = '1' Then
				End If;

				If run(Z08) = '1' Then
					Z09_osc_1Hz_sf <= sfixed(osc_1Hz);
				End If;

				If run(Z09) = '1' Then
					Z10_SineIndexsf <= resize(to_sfixed(SineIndex(Z09)), Z10_SineIndexsf, fixed_wrap, fixed_truncate);
					Z10_Osc <= resize(Z09_freq_hz * Z09_osc_1Hz_sf, Z10_Osc, fixed_wrap, fixed_truncate);
					Z10_FM_Factor_sf <= sfixed(Z09_FM_Factor);
				End If;

				If run(Z10) = '1' Then
					Z11_SineIndexsf  <= Z10_SineIndexsf;
					Z11_FM_Mod_Phase <= resize(Z10_Osc * Z10_FM_Factor_sf, Z11_FM_Mod_Phase, fixed_wrap, fixed_truncate);
					Z11_NoteRelSineIndexsf <= resize(NoteRelSineIndexsf(Z10), Z11_NoteRelSineIndexsf);
				End If;
				
				If run(Z11) = '1' Then
					Z12_SineIndexNormal <= resize(Z11_SineIndexsf * to_sfixed(SINETOCTRL, -10, -TOTAL_SINES_ADDRBW - 10), Z12_SineIndexNormal, fixed_wrap, fixed_truncate);
				End If;
				If run(Z13) = '1' Then
					Z14_FM_Mod <= Z17_FM_Mod; -- ignore for now
				End If;

				If run(Z14) = '1' Then
					Z15_iProd0 <= Z14_envelope_effect;
					Z15_pbend_effect <= sfixed(Z14_pbend_effect);
					--Z15_pbend_effect <= resize(Z14_pbend_effect * to_sfixed(1200 * 5, PROCESS_BW-1, 0), Z15_pbend_effect, fixed_wrap, fixed_truncate); -- 5 octave max pitchbend
					Z15_FM_Mod <= resize(Z14_FM_Mod * Z18_FM_DEPTH, Z15_FM_Mod, fixed_wrap, fixed_truncate);
				End If;

				If run(Z15) = '1' Then
					Z16_pbend_fm <= resize(Z15_pbend_effect + Z15_FM_Mod, Z16_pbend_fm, fixed_wrap, fixed_truncate);
					Z16_iProd0 <= Z15_iProd0;
					Z16_SineIndexsf(TOTAL_SINES_ADDRBW - 1 Downto 0) <= sfixed(SineIndex(Z15));
				End If;

				If run(Z16) = '1' Then
					Z17_bent_fm_index <= resize(Z16_pbend_fm + Z16_SineIndexsf, Z17_bent_fm_index, fixed_wrap, fixed_truncate);
					Z17_iProd0 <= resize(Z16_nfilter_effect * Z16_iProd0, Z17_iProd0, fixed_wrap, fixed_truncate);
				End If;

				-- sum up the results of effects
				If run(Z17) = '1' Then
					Z18_FM_DEPTH <= sfixed(Z17_FM_DEPTH);
					Z18_iProd0 <= Z17_iProd0;
					Z18_iProd1 <= resize(Z17_gfilter_effect * Z17_hwidth_effect, Z17_iProd0, fixed_wrap, fixed_truncate);
					Z18_bent_fm_bank_index <= Std_logic_vector(Z17_bent_fm_index);
				End If;

				If run(Z18) = '1' Then
					Z19_iProd1 <= resize(Z18_iProd1 * Z18_iProd0, Z19_iProd1, fixed_wrap, fixed_truncate);
					Z19_bent_index <= Z18_bent_fm_bank_index(SINESPERBANK_ADDRBW - 1 Downto 0);
					Z19_bent_bank <= to_integer(unsigned(Z18_bent_fm_bank_index(BANKCOUNT_ADDRBW + SINESPERBANK_ADDRBW - 1 Downto SINESPERBANK_ADDRBW)));
				End If;

				If run(Z19) = '1' Then
					Z20_iProd1 <= Z19_iProd1;
					Z20_bent_bank <= Z19_bent_bank;
					Z20_bent_index <= Z19_bent_index;
				End If;

				If run(Z20) = '1' Then
					Z21_bent_bank <= Z20_bent_bank;
					Z21_bent_index <= Z20_bent_index;
					Z21_extant_ampsf <= sfixed(Z20_extant_amp(Z20_bent_bank));
					Z21_iProd1 <= Z20_iProd1;
				End If;

				Z22_extant_amp_wren <= (Others => '0');
				Z22_amparray_wren_int <= (Others => '0');
				Z22_lastupdated_wren  <= '0';
				If run(Z21) = '1' Then
                    Z22_lastupdated_wren  <= '1';
					Z22_amparray_wraddr_int <= Z21_bent_index;
					-- this code is still double sometimes
					Z22_amparray_CURRCYCLE <= Std_logic_vector(CURRCYCLE(Z21));
					-- if this is the first time being written to this cycle
					If Z21_LAST_UPDATED(Z21_Bent_bank) /= CURRCYCLE(Z21) Then
						Z22_extant_amp <= Std_logic_vector(Z21_iProd1);
						-- write out the old read
						Z22_amparray_wrdata <= Std_logic_vector(Z21_extant_ampsf(Z21_extant_ampsf'high Downto Z21_extant_ampsf'high + 1 - VOLUMEPRECISION));
						Z22_amparray_wren_int(Z21_bent_bank) <= '1';
					Else
						-- otherwise, add to the extant data (consider max vs addition) 
						Z22_extant_amp <= Std_logic_vector(resize(Z21_iProd1 + Z21_extant_ampsf, Z18_iProd1, fixed_wrap, fixed_truncate));
--						if Z21_iProd1 > Z21_extant_ampsf then
--						      Z22_extant_amp <= Std_logic_vector(resize(Z21_iProd1, Z18_iProd1, fixed_wrap, fixed_truncate));
--						else
--						      Z22_extant_amp <= Std_logic_vector(resize(Z21_extant_ampsf, Z18_iProd1, fixed_wrap, fixed_truncate));
--                        end if;
					End If;

					-- always store the extant data
					Z22_extant_amp_wren(Z21_bent_bank) <= '1';
					Z22_extant_amp_wraddr <= Z21_bent_index;
				End If;
				addrloop :
				For i In Z02 To run'high Loop
					If run(i - 1) = '1' Then
						NoteIndex(i) <= NoteIndex(i - 1);
					End If;
				End Loop;
				addrloop2 :
				For i In Z04 To run'high Loop
					If run(i - 1) = '1' Then
						SineIndex(i) <= SineIndex(i - 1);
					End If;
				End Loop;
				addrloop3 :
				For i In Z04 To NoteRelSineIndexsf'high Loop
					If run(i - 1) = '1' Then
						NoteRelSineIndexsf(i) <= NoteRelSineIndexsf(i - 1);
					End If;
				End Loop;
				addrloop4 :
				For i In Z06 To Centsf'high Loop
					If run(i - 1) = '1' Then
						Centsf(i) <= Centsf(i - 1);
					End If;
				End Loop;
				addrloop5 :
				For i In Z02 To CURRCYCLE'high Loop
					If run(i - 1) = '1' Then
						CURRCYCLE(i) <= CURRCYCLE(i - 1);
					End If;
				End Loop;
				-- if in reset:    
			Else
				--Z22_amparray_wren_int <= '0';    
			End If;
		End If;
	End Process;

	-- combine generated reset requests into a single output queue
	IRQueue : Entity work.fifo_stream
		Port Map(
			clk => clk,
			rst => rst,
			din_ready => IRQueue_in_ready,
			din_valid => IRQueue_in_valid,
			din_data => IRQueue_in_data,
			dout_ready => IRQueue_out_ready,
			dout_valid => IRQueue_out_valid,
			dout_data => IRQueue_out_data
		);

	pbend_env_finished_ready <= '1' When currentIRQueueSource = 0 Else '0';
	hwidth_env_finished_ready <= '1' When currentIRQueueSource = 1 Else '0';
	nfilter_env_finished_ready <= '1' When currentIRQueueSource = 2 Else '0';
	gfilter_env_finished_ready <= '1' When currentIRQueueSource = 3 Else '0';
	envelope_env_finished_ready <= '1' When currentIRQueueSource = 4 Else '0';

	IRQueue_in_valid <= pbend_env_finished_valid When currentIRQueueSource = 0 Else
		hwidth_env_finished_valid When currentIRQueueSource = 1 Else
		nfilter_env_finished_valid When currentIRQueueSource = 2 Else
		gfilter_env_finished_valid When currentIRQueueSource = 3 Else
		envelope_env_finished_valid When currentIRQueueSource = 4;

	IRQueue_in_data(15 Downto 8) <= Std_logic_vector(to_unsigned(currentIRQueueSource, 8));
	IRQueue_in_data(7) <= '0';
	IRQueue_in_data(6 Downto 0) <=
	pbend_env_finished_addr When currentIRQueueSource = 0 Else
	hwidth_env_finished_addr When currentIRQueueSource = 1 Else
	nfilter_env_finished_addr When currentIRQueueSource = 2 Else
	gfilter_env_finished_addr When currentIRQueueSource = 3 Else
	envelope_env_finished_addr When currentIRQueueSource = 4;

	-- IRqueue process
	-- Combine all reset reqd signals into a single output queue
	irqueue_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			If rst = '0' Then
				currentIRQueueSource <= currentIRQueueSource + 1;
				If currentIRQueueSource = 9 Then
					currentIRQueueSource <= 0;
				End If;
				-- if in reset:    
			Else
			End If;
		End If;
	End Process;

End arch_imp;