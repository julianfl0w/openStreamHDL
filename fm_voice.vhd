----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;
Use ieee.math_real.All;

Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;
Library UNISIM;
Use UNISIM.vcomponents.All;

Library UNIMACRO;
Use UNIMACRO.vcomponents.All;
Library work;
Use work.spectral_pkg.All;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity fm_voice Is
	Generic (
		USE_MLMM : Integer := 1;
		VOICECOUNT : Integer := 512;
		VOICECOUNTLOG2 : Integer := 9;
		PROCESS_BW : Integer := 18;
		CHANNEL_COUNT : Integer := 2;
		VOLUMEPRECISION : Integer := 16;
		PHASE_PRECISION : Integer := 32;
		CYCLE_BW : Integer := 3;
		LFO_COUNT : Integer := 2;
		OPERATOR_COUNT : Integer := 8;
		OPERATOR_COUNT_LOG2 : Integer := 3;
		FMSRC_COUNT_LOG2 : Integer := 4;
		SINESPERBANK_VoiceIndexBW : Integer := 10
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		
		wren_array : In Std_logic_vector(127 Downto 0) := (Others => '0');

		mm_addr : In Std_logic_vector(31 Downto 0) := (Others => '0');
		mm_wrdata   : In Std_logic_vector(31 Downto 0) := (Others => '0');
		mm_voiceno0 : In Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		mm_voiceno1 : In Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		mm_voiceno2 : In Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		mm_wrdata_processbw : In Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
		mm_wrdata_algorithm : In Std_logic_vector(OPERATOR_COUNT * OPERATOR_COUNT_LOG2 - 1 Downto 0) := (Others => '0');

		mm_opno_onehot : In Std_logic_vector(OPERATOR_COUNT - 1 Downto 0) := (Others => '0');
		
        
        passthrough : In Std_logic;
        
        Z14_voiceamp_ready : In Std_logic;
		Z14_voiceamp_data  : Out sfixed(1 Downto -PROCESS_BW - OPERATOR_COUNT_LOG2 + 2);
		Z14_voiceamp_valid : Out Std_logic;
		Z14_voiceIndex : out Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		
        irqueue_in_data  : out STD_LOGIC_VECTOR(VOICECOUNTLOG2+OPERATOR_COUNT*2 - 1 Downto 0);
        irqueue_in_ready : in  std_logic;
        irqueue_in_valid : out std_logic

	);

End fm_voice;

Architecture arch_imp Of fm_voice Is
	Attribute mark_debug : String;
    
	Constant COUNTER_WIDTH : Integer := 32;
	Signal Z09_PitchLfo : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');

	--Attribute mark_debug Of mm_wrdata : Signal Is "true";

	Signal run : Std_logic_vector(Z13 Downto Z00) := (Others => '0');
	Signal Z03_run : Std_logic_vector(run'high - Z03 Downto Z00) := (Others => '0');
	Signal Z05_run : Std_logic_vector(run'high - Z05 Downto Z00) := (Others => '0');
	--Attribute mark_debug Of run : Signal Is "true";
	Type addrtype Is Array(Z01 To run'high) Of Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
	Signal VoiceIndex : addrtype := (Others => (Others => '0'));
	Signal Z00_VoiceIndex : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0) := (Others => '0');

	Signal Z02_am_algo : Std_logic_vector(OPERATOR_COUNT * FMSRC_COUNT_LOG2 - 1 Downto 0);

	Signal Z02_operator_output : OPERATOR_PROCESS;
	Signal Z02_osc0_output : Std_logic_vector(PROCESS_BW - 1 Downto 0);
	Signal Z03_pitchlfo : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z04_pitchlfo : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z04_pitchlfo_gated : OPERATOR_PROCESS;
	Signal Z13_env_finished : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);
	Signal Z13_inc_finished : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);

	Signal Z02_feedback_antihunt : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z06_feedback_src : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z07_feedback_postgain : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z07_feedback_postgain_slv : Std_logic_vector(PROCESS_BW - 1 Downto 0);
	Signal Z05_sounding : Std_logic_vector(PROCESS_BW - 1 Downto 0);
	Signal Z05_opout_data : OPERATOR_PROCESS;
	Signal Z05_opout_data_sounding : OPERATOR_PROCESS;
	Signal Z06_volume_lfo : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z07_volume_lfo : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z08_volume_lfo : sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z02_fm_algo : Std_logic_vector(OPERATOR_COUNT * FMSRC_COUNT_LOG2 - 1 Downto 0);
	Signal mm_wrdata_fmalgo : Std_logic_vector(OPERATOR_COUNT * FMSRC_COUNT_LOG2 - 1 Downto 0);
    Type OPERATOR_ARRAY_SEL Is Array(0 To OPCOUNT - 1) Of unsigned(FMSRC_COUNT_LOG2 - 1 Downto 0);
	Signal Z02_fmsrc_index : OPERATOR_ARRAY_SEL;
	Signal Z02_amsrc_index : OPERATOR_ARRAY_SEL;

	Signal Z05_fb_srcindex : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');

	Signal Z08_voice_amp : sfixed(OPERATOR_COUNT_LOG2 + 1 Downto -PROCESS_BW + 2);
	Signal Z08_voice_amp_slv : Std_logic_vector(OPERATOR_COUNT_LOG2 + PROCESS_BW - 1 Downto 0);
	Signal Z09_voice_amp : sfixed(OPERATOR_COUNT_LOG2 + 1 Downto -PROCESS_BW + 2);
	Signal Z09_voice_amp_slv : Std_logic_vector(OPERATOR_COUNT_LOG2 + PROCESS_BW - 1 Downto 0);

	Signal Z10_voiceamp_data     : Std_logic_vector(OPERATOR_COUNT_LOG2 + PROCESS_BW - 1 Downto 0);
	Signal Z11_voiceamp_data     : sfixed(1 Downto -PROCESS_BW - OPERATOR_COUNT_LOG2 + 2);
	Signal Z12_voiceamp_data     : sfixed(1 Downto -PROCESS_BW - OPERATOR_COUNT_LOG2 + 2);
	Signal Z13_voiceamp_data     : sfixed(1 Downto -PROCESS_BW - OPERATOR_COUNT_LOG2 + 2);

	Signal env_wr_sel : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);
	Signal envrate_wr_sel : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);
	
Begin
    mm_wrdata_fmalgo <= mm_wrdata(OPERATOR_COUNT * FMSRC_COUNT_LOG2 - 1 Downto 0);
	Z07_feedback_postgain_slv <= Std_logic_vector(Z07_feedback_postgain);
	Z08_voice_amp_slv <= Std_logic_vector(Z08_voice_amp);
	Z09_voice_amp_slv <= Std_logic_vector(Z09_voice_amp);
	Z02_osc0_output <= Std_logic_vector(Z02_operator_output(0));
	Z03_run <= run(run'high Downto Z03);
	Z05_run <= run(run'high Downto Z05);
	
	-- I/O Connections assignments
	flow_i : Entity work.flow
		Port Map(
			clk => clk,
			rst => rst,

			in_ready => Open,
			in_valid => '1', -- its a synth baby
			out_ready => Z14_voiceamp_ready,
			out_valid => Z14_voiceamp_valid,

			run => run
		);

	-- some  voice params
	fm_algo_i : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceno2,
			wrdata => mm_wrdata_fmalgo,
			wren => wren_array(cmd_fm_algo),
			rden => run(Z01),
			rdaddr => VoiceIndex(Z01),
			rddata => Z02_fm_algo
		);

	-- some  voice params
	sounding_i : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceno2,
			wrdata => mm_wrdata_processbw,
			wren => wren_array(cmd_sounding),
			rden => run(Z04),
			rdaddr => VoiceIndex(Z04),
			rddata => Z05_sounding
		);
		
	am_algo_i : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceno1,
			wrdata => mm_wrdata_fmalgo,
			wren => wren_array(cmd_am_algo),
			rden => run(Z01),
			rdaddr => VoiceIndex(Z01),
			rddata => Z02_am_algo
		);

	fbsrc_i : Entity work.simple_dual_one_clock
		Port Map(
			clk => clk,
			wea => '1',
			wraddr => mm_voiceno1,
			wrdata => mm_wrdata_processbw,
			wren => wren_array(cmd_fbsrc),
			rden => run(Z04),
			rdaddr => VoiceIndex(Z04),
			rddata => Z05_fb_srcindex
		);

	fbgain_i : Entity work.mm_volume
		Port Map(
			run => run,
			clk => clk,

			gain_wr => wren_array(cmd_fbgain),
			mm_voiceno => mm_voiceno0,
			mm_wrdata_processbw => mm_wrdata_processbw,
			Z00_VoiceIndex => VoiceIndex(Z04),

			Z02_din_data => Z06_feedback_src,
			Z03_dout_data => Z07_feedback_postgain
		);

	antihunting_i : Entity work.antihunting
		Port Map(
			run => Z05_run,
			clk => clk,

			Z00_VoiceIndex => VoiceIndex(Z05),
			Z02_din_DATA => Z07_feedback_postgain,

			srun          => run,
			S00_rdaddr    => Z00_VoiceIndex,
			S02_dout_DATA => Z02_feedback_antihunt
		);

	opgen :
	For operator In 0 To OPERATOR_COUNT - 1 Generate
        Z04_pitchlfo_gated(operator) <= Z04_pitchlfo when operator < 6 else (others=>'0');
		Z05_opout_data_sounding(operator) <= Z05_opout_data(operator) When Z05_sounding(operator) = '1' Else (Others => '0');
		Z02_fmsrc_index(operator) <= unsigned(Z02_fm_algo(((operator + 1) * FMSRC_COUNT_LOG2) - 1 Downto operator * FMSRC_COUNT_LOG2));
		Z02_amsrc_index(operator) <= unsigned(Z02_am_algo(((operator + 1) * FMSRC_COUNT_LOG2) - 1 Downto operator * FMSRC_COUNT_LOG2));

		env_wr_sel(operator) <= wren_array(cmd_env) And mm_opno_onehot(operator);
		envrate_wr_sel(operator) <= wren_array(cmd_env_rate) And mm_opno_onehot(operator);
	End Generate;

	opgen2 :
	For operator In 1 To OPERATOR_COUNT - 1 Generate
		mm_operator_i : Entity work.mm_operator 
			Generic Map(
				VOICECOUNT => VOICECOUNT,
				VOICECOUNTLOG2 => VOICECOUNTLOG2,
				PROCESS_BW => PROCESS_BW,
				OPERATOR_COUNT => OPERATOR_COUNT,
				OPERATOR_COUNT_LOG2 => OPERATOR_COUNT_LOG2,
				OPERATOR_NUMBER => operator,
				DEBUG_ON => "false"
			)
			Port Map(
				clk => clk,
				rst => rst,
				run => run,

				wren_array => wren_array,

				env_wr => env_wr_sel(operator),
				envrate_wr => envrate_wr_sel(operator),
				Z13_env_finished => Z13_env_finished(operator),
				Z13_inc_finished => Z13_inc_finished(operator),

				Z01_VoiceIndex => VoiceIndex(Z01),
				Z02_VoiceIndex => VoiceIndex(Z02),
				Z03_VoiceIndex => VoiceIndex(Z03),
				Z09_VoiceIndex => VoiceIndex(Z09),
				Z12_VoiceIndex => VoiceIndex(Z12),
				Z02_fb_in => Z02_feedback_antihunt,

				Z04_pitchlfo => Z04_pitchlfo_gated(operator),

				Z02_fm_src_index => Z02_fmsrc_index(operator),
				Z02_am_src_index => Z02_amsrc_index(operator),

				Z02_operator_output => Z02_operator_output(operator),
				Z02_operators => Z02_operator_output,
				Z05_opout_data => Z05_opout_data(operator),
                passthrough => passthrough,
                
				cs => mm_opno_onehot(operator),
				mm_addr => mm_addr,
				mm_voiceno => mm_voiceno0,
				mm_wrdata => mm_wrdata,
				mm_wrdata_processbw => mm_wrdata_processbw

			);
	End Generate;

    mm_operator_i : Entity work.mm_operator 
        Generic Map(
            VOICECOUNT => VOICECOUNT,
            VOICECOUNTLOG2 => VOICECOUNTLOG2,
            PROCESS_BW => PROCESS_BW,
            OPERATOR_COUNT => OPERATOR_COUNT,
            OPERATOR_COUNT_LOG2 => OPERATOR_COUNT_LOG2,
            OPERATOR_NUMBER => 0,
            DEBUG_ON => "false"
        )
        Port Map(
            clk => clk,
            rst => rst,
            run => run,

            wren_array => wren_array,

            env_wr => env_wr_sel(0),
            envrate_wr => envrate_wr_sel(0),
            Z13_env_finished => Z13_env_finished(0),
            Z13_inc_finished => Z13_inc_finished(0),

            Z01_VoiceIndex => VoiceIndex(Z01),
            Z02_VoiceIndex => VoiceIndex(Z02),
            Z03_VoiceIndex => VoiceIndex(Z03),
            Z09_VoiceIndex => VoiceIndex(Z09),
            Z12_VoiceIndex => VoiceIndex(Z12),
            Z02_fb_in => Z02_feedback_antihunt,

            Z04_pitchlfo => Z04_pitchlfo_gated(0),

            Z02_fm_src_index => Z02_fmsrc_index(0),
            Z02_am_src_index => Z02_amsrc_index(0),

            Z02_operator_output => Z02_operator_output(0),
            Z02_operators => Z02_operator_output,
            Z05_opout_data => Z05_opout_data(0),

            passthrough => passthrough,
            cs => mm_opno_onehot(0),
            mm_addr => mm_addr,
            mm_voiceno => mm_voiceno0,
            mm_wrdata => mm_wrdata,
            mm_wrdata_processbw => mm_wrdata_processbw

        );
			
	sum8_i : Entity work.sum8
		Port Map(
			run => Z05_run,
			clk => clk,

			Z00_all8 => Z05_opout_data_sounding,
			Z03_sum_out => Z08_voice_amp
		);
	ctrlproc :
	Process (clk)
	Begin
		If rising_edge(clk) Then

			If rst = '0' Then

				addrloop :
				For i In Z02 To VoiceIndex'HIGH Loop
					If run(i - 1) = '1' Then
						VoiceIndex(i) <= VoiceIndex(i - 1);
					End If;
				End Loop;

				If run(Z00) = '1' Then
					Z00_VoiceIndex <= Std_logic_vector(unsigned(Z00_VoiceIndex) + 1);
					VoiceIndex(Z01) <= Z00_VoiceIndex;
				End If;

				If run(Z02) = '1' Then
					Z03_pitchlfo <= Z02_operator_output(7);
				End If;

				If run(Z03) = '1' Then
					Z04_pitchlfo <= Z03_pitchlfo;
				End If;
				If run(Z04) = '1' Then
				End If;
				If run(Z05) = '1' Then
					Z06_volume_lfo <= Z05_opout_data(6);
					Z06_feedback_src <= Z05_opout_data(to_integer(unsigned(Z05_fb_srcindex)));
				End If;

				If run(Z06) = '1' Then
					Z07_volume_lfo <= resize(Z06_volume_lfo, Z07_volume_lfo, fixed_wrap, fixed_truncate);
				End If;
				If run(Z07) = '1' Then
				    if passthrough = '0' then
					   Z08_volume_lfo <= resize(Z07_volume_lfo + 0.5, Z08_volume_lfo, fixed_wrap, fixed_truncate);
                    else
					   Z08_volume_lfo <= to_sfixed(1.0, Z08_volume_lfo);
                    end if;
				End If;
				If run(Z08) = '1' Then
					Z09_voice_amp <= resize(Z08_voice_amp * Z08_volume_lfo, Z09_voice_amp, fixed_wrap, fixed_truncate);
				End If;
				If run(Z09) = '1' Then
					Z10_voiceamp_data <= std_logic_vector(Z09_voice_amp);
				End If;
				If run(Z10) = '1' Then
					Z11_voiceamp_data <= to_sfixed(Z10_voiceamp_data, Z11_voiceamp_data);
				End If;
				If run(Z11) = '1' Then
					Z12_voiceamp_data <= resize(Z11_voiceamp_data, Z12_voiceamp_data, fixed_wrap, fixed_truncate);
					--Z12_voiceamp_data <= resize(sfixed(to_stdlogicvector(to_bitvector(std_logic_vector(Z11_voiceamp_data)) sra 6)), Z12_voiceamp_data, fixed_wrap, fixed_truncate);
				End If;
				If run(Z12) = '1' Then
				    Z13_voiceamp_data <= Z12_voiceamp_data;
				End If;
				
                irqueue_in_valid <= '0';
				If run(Z13) = '1' Then
					Z14_voiceamp_data <= Z13_voiceamp_data;
                    Z14_voiceIndex <= VoiceIndex(Z13);
                    
                    if unsigned(Z13_env_finished) /= 0 or unsigned(Z13_inc_finished) /= 0 then
                        irqueue_in_data  <= Z13_inc_finished & Z13_env_finished & VoiceIndex(Z13);
                        irqueue_in_valid <= '1';
                    end if;
				End If;

			End If;
		End If;
	End Process;
End arch_imp;