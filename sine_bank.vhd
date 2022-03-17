Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity sine_bank Is
	Generic (
		PROCESS_BW : Integer := 25;
		PHASEPRECISION : Integer := 32;
		VOLUMEPRECISION : Integer := 16;
		I2s_BITDEPTH : Integer := 16;
		BANKCOUNT : Integer := 12;
		SINESPERBANK : Integer := 1024;
		SINESPERBANK_ADDRBW : Integer := 10;
		CYCLE_BW : Integer := 3;
		CHANNEL_COUNT : Integer := 2
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;

        gain_wr  : in std_logic;
		mm_wraddr : In Std_logic_vector;
		mm_wrdata : In Std_logic_vector;
		
		Z00_volume_wren : In Std_logic_vector(BANKCOUNT - 1 Downto 0);
		Z00_volume_wrdata : In Std_logic_vector(VOLUMEPRECISION - 1 Downto 0);
		Z00_volume_wraddr : In Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0);
		Z00_volume_currcycle : In Std_logic_vector(CYCLE_BW - 1 Downto 0);

		S17_PCM_TVALID : Out Std_logic;
		S17_PCM_TREADY : In Std_logic;
		S17_PCM_TDATA : Out Std_logic_vector(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0')
	);
End sine_bank;

Architecture arch_imp Of sine_bank Is

	Signal mm_wrdata_processbw : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal selectionBit : Std_logic := '0';
	Signal run_S09downtoS04 : Std_logic_vector(S05 Downto 0);

	Signal S17_sum_left  : sfixed(12 Downto -PHASEPRECISION + 2) := (Others => '0');
	Signal S17_sum_right : sfixed(12 Downto -PHASEPRECISION + 2) := (Others => '0');

	Type S01_RVTYPE Is Array (0 To BANKCOUNT - 1) Of Std_logic_vector(PHASEPRECISION - 1 Downto 0);
	Signal S02_RandVal : S01_RVTYPE := (Others => (Others => '0'));

	Signal seed_rst : Std_logic := '0';
	Type BANKAMPTYPE Is Array (0 To BANKCOUNT - 1) Of Std_logic_vector(VOLUMEPRECISION - 1 Downto 0);
	Signal S07_amplitude_presmooth : BANKAMPTYPE := (Others => (Others => '0'));
	Type BANKAMPTYPEsf Is Array (0 To BANKCOUNT - 1) Of sfixed(1 Downto -VOLUMEPRECISION + 2);
	Signal S08_amplitude_presmooth : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S09_amplitude_presmooth : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S07_amplitude : BANKAMPTYPE := (Others => (Others => '0'));
	Signal S08_amplitude : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S09_amplitude : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S09_difference : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S10_amplitude : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S10_TEST_amplitude : sfixed(1 Downto -VOLUMEPRECISION + 2) := (Others => '0');
	Signal S11_amplitude : BANKAMPTYPEsf := (Others => (Others => '0'));
	Signal S12_amplitude : BANKAMPTYPE := (Others => (Others => '0'));

	Constant dec_amount : sfixed(1 Downto -VOLUMEPRECISION + 2) := to_sfixed(0.025, 1, -VOLUMEPRECISION + 2);
	Type PHASE_AMPTYPE_SLV Is Array (0 To BANKCOUNT - 1) Of Std_logic_vector(PHASEPRECISION - 1 Downto 0);
    Type PHASE_AMPTYPE_UNS Is Array (0 To BANKCOUNT - 1) Of unsigned(PHASEPRECISION - 1 Downto 0);
	Type PHASE_AMPTYPE_U Is Array (0 To BANKCOUNT - 1) Of ufixed(0 Downto -PHASEPRECISION + 1);
	Type PHASE_AMPTYPE_S Is Array (0 To BANKCOUNT - 1) Of sfixed(0 Downto -PHASEPRECISION + 1);
	Type PHASE_AMPTYPE_SIGNED Is Array (0 To BANKCOUNT - 1) Of signed(PHASEPRECISION - 1 Downto 0);
	Type PROCESS_S Is Array (0 To BANKCOUNT - 1) Of sfixed(1 Downto -PROCESS_BW + 2);
	Signal S12_sine_adjusted : PHASE_AMPTYPE_S := (Others => (Others => '0'));
	Signal S10_SINE_out : PROCESS_S := (Others => (Others => '0'));
	Signal S11_SINE_out : PROCESS_S := (Others => (Others => '0'));
	-- the index for base index 4800
	Signal S12_TEST_SINE_out : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S01_increment  : ufixed(0 Downto -PHASEPRECISION + 1) := (others=>'0');
	Signal S02_TEST_phase : ufixed(0 Downto -PHASEPRECISION + 1) := (others=>'0');
	Signal S01_phase : Std_logic_vector(PHASEPRECISION - 1 Downto 0) := (others => '0');
	Signal S02_phase : PHASE_AMPTYPE_UNS := (Others => (Others => '0'));
	Signal S02_increment  : ufixed(0 Downto -PHASEPRECISION + 1) := (others=>'0');
	Signal S02_phasenext  : ufixed(0 Downto -PHASEPRECISION + 1) := (others=>'0');
	Signal S03_phasenext : Std_logic_vector(PHASEPRECISION - 1 Downto 0) := (others => '0');
	Signal S03_phase_dither : PHASE_AMPTYPE_UNS := (Others => (Others => '0'));
	Signal S04_phase_dither : PHASE_AMPTYPE_SLV := (Others => (Others => '0'));
	Signal S03_TEST_phase : signed(PHASEPRECISION - 1 Downto 0) := (Others => '0');
	Signal S13_TEST_sine_adjusted : sfixed(1 Downto -PHASEPRECISION + 2) := (Others => '0');

	Type sadrtype Is Array(S01 To S17) Of Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0);
	Signal S00_sadr : unsigned(SINESPERBANK_ADDRBW - 1 Downto 0) := (Others => '0');
	Signal sadr : sadrtype := (Others => (Others => '0'));
	Signal srun : Std_logic_vector(sadr'high Downto Z00) := (Others => '0');

	Signal S13_BANK_0_1 : sfixed(2 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S13_BANK_2_3 : sfixed(2 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S13_BANK_4_5 : sfixed(2 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S13_BANK_6_7 : sfixed(2 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S13_BANK_8_9 : sfixed(2 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal S14_BANK_0_1_2_3 : sfixed(3 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S14_BANK_4_5_6_7 : sfixed(3 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S14_BANK_8_9 : sfixed(3 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal S15_TOTAL : sfixed(4 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S16_TOTAL_left : sfixed(4 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal S16_TOTAL_right: sfixed(4 Downto -PROCESS_BW + 2) := (Others => '0');
	Signal GAIN_left : sfixed(PROCESS_BW - 1 downto 0) := to_sfixed(1, PROCESS_BW - 1, 0);
	Signal GAIN_right: sfixed(PROCESS_BW - 1 downto 0) := to_sfixed(1, PROCESS_BW - 1, 0);
	
	Signal S17_READY : Std_logic := '0';
	Signal S17_PCM_TVALID_int : Std_logic := '0';

	Type S07_lastupdateTYPE Is Array (0 To BANKCOUNT - 1) Of Std_logic_vector(CYCLE_BW - 1 Downto 0);
	Signal S07_lastupdate : S07_lastupdateTYPE := (Others => (Others => '0'));

	Constant E_INC : PHASE_AMPTYPE_U :=
		(
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 0.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 1.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 2.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 3.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 4.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 5.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 6.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 7.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 8.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 9.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 10.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1),
		to_ufixed((E0_FREQ_HZ * (2 ** (real(SINESPERBANK) * 11.0/1200.0)))/FS_HZ_REAL, 0, -PHASEPRECISION + 1)
		);
	Function byteswap32(data : In Std_logic_vector(31 Downto 0)) Return Std_logic_vector Is Begin
		Return data(7 Downto 0) &
		data(15 Downto 8) &
		data(23 Downto 16) &
		data(31 Downto 24);
	End;

Begin

	mm_wrdata_processbw <= mm_wrdata(PROCESS_BW - 1 Downto 0);
	run_S09downtoS04 <= srun(S09 Downto S04);
	S17_PCM_TVALID <= S17_PCM_TVALID_int;
	S17_READY <= Not S17_PCM_TVALID_int;

    phaseBram : Entity work.simple_dual_one_clock
        Generic Map(
            DATA_WIDTH => PHASEPRECISION,
            ADDR_WIDTH => SINESPERBANK_ADDRBW
        )
        Port Map(
            clk    => clk,
            wea    => '1',
            wraddr => sadr(S03),
            wren   => srun(S03),
            wrdata => S03_phasenext,
            rden   => srun(S00),
            rdaddr => Std_logic_vector(S00_sadr),
            rddata => S01_phase
        );
        

	-- solve each bank independantly
	banks :
	For bank In 0 To BANKCOUNT - 1 Generate
		lastupdatedArray : Entity work.simple_dual_one_clock
			Generic Map(
				DATA_WIDTH => CYCLE_BW,
				ADDR_WIDTH => SINESPERBANK_ADDRBW
			)
			Port Map(
				clk => clk,
				wea => '1',
				wren => Z00_volume_wren(bank),
				wraddr => Z00_volume_wraddr,
				wrdata => Z00_volume_currcycle,
				rden => srun (S06),
				rdaddr => sadr(S06),
				rddata => S07_lastupdate(bank)
			);

		lsfr_i : Entity work.LFSR
			Generic Map(
				g_Num_Bits => PHASEPRECISION
			)
			Port Map(
				Clk => Clk,
				Enable => srun(S01),

				Seed_DV => seed_rst,
				Seed_Data => Std_logic_vector(E_INC(bank)),

				LFSR_Data => S02_RandVal(bank),
				LFSR_Done => Open
			);

		-- we need to periodically reduce these values 
		-- so they dont get stuck
		preSmoothedVolumeBram : Entity work.simple_dual_one_clock
			Generic Map(
				DATA_WIDTH => VOLUMEPRECISION,
				ADDR_WIDTH => SINESPERBANK_ADDRBW
			)
			Port Map(
				clk => clk,
				wea => '1',
				wraddr => Z00_volume_wraddr,
				wrdata => Z00_volume_wrdata,
				wren => Z00_volume_wren(bank),
				rden => srun(S06),
				rdaddr => sadr(S06),
				rddata => S07_amplitude_presmooth(bank)
			);

		smoothedVolumeBram : Entity work.simple_dual_one_clock
			Generic Map(
				DATA_WIDTH => VOLUMEPRECISION,
				ADDR_WIDTH => SINESPERBANK_ADDRBW
			)
			Port Map(
				clk => clk,
				wea => '1',
				wraddr => sadr(S12),
				wren   => srun(S12),
				wrdata => S12_amplitude(bank),
				rden   => srun(S06),
				rdaddr => sadr(S06),
				rddata => S07_amplitude(bank)
			);

		i_sine_lookup : Entity work.sine_lookup
			Generic Map(
				OUT_BW => 25,
				PHASE_WIDTH => 32
			)
			Port Map(
				clk => clk,
				rst => rst,
				Z00_PHASE_in => signed(S04_phase_dither(bank)),
				Z06_SINE_out => S10_SINE_out(bank),
				run => run_S09downtoS04
			);

		-- sine process
		-- all output from ram
		sineproc :
		Process (clk)
		Begin
			If rising_edge(clk) Then

				If rst = '0' Then

					addrloop :
					For i In S02 To sadr'high Loop
						If srun(i - 1) = '1' Then
							sadr(i) <= sadr(i - 1);
						End If;
					End Loop;

					If srun(S00) = '1' Then
						S00_sadr <= S00_sadr + 1;
						sadr(S01) <= Std_logic_vector(S00_sadr);
					End If;

					If srun(S01) = '1' Then
						S02_phase(bank) <= resize(unsigned(S01_phase) * (2**bank), S02_phase(bank)'length);
					End If;

					If srun(S02) = '1' Then
					    S03_phase_dither(bank)  <=  resize(S02_phase(bank) + unsigned(S02_RandVal(bank)), S02_phase(bank)'length);
					End If;
					
					If srun(S03) = '1' Then
					    S04_phase_dither(bank)  <=  std_logic_vector(S03_phase_dither(bank));
					End If;

					If srun(S07) = '1' Then
						-- if this data is old, send smoothed function to zero
						If unsigned(Z00_volume_currcycle) - unsigned(S07_lastupdate(bank)) > 3 Then
							S08_amplitude_presmooth(bank) <= (Others => '0');
						Else
							S08_amplitude_presmooth(bank) <= sfixed(S07_amplitude_presmooth(bank));
						End If;
						S08_amplitude(bank) <= sfixed(S07_amplitude(bank));
					End If;

					If srun(S08) = '1' Then
						S09_amplitude(bank)           <= S08_amplitude(bank);
						S09_amplitude_presmooth(bank) <= S08_amplitude_presmooth(bank);
						S09_difference(bank)          <= resize(S08_amplitude_presmooth(bank) - S08_amplitude(bank), S09_difference(bank), fixed_saturate, fixed_truncate);
					End If;

					If srun(S09) = '1' Then
						-- chase the prescale
						If S09_difference(bank) > dec_amount Then
							S10_amplitude(bank) <= resize(S09_amplitude(bank) + dec_amount, S10_amplitude(bank), fixed_wrap, fixed_truncate);
						Elsif S09_difference(bank) < -dec_amount Then
							S10_amplitude(bank) <= resize(S09_amplitude(bank) - dec_amount, S10_amplitude(bank), fixed_wrap, fixed_truncate);
						Else
							--S10_amplitude(bank) <= resize(S09_amplitude(bank) + S09_difference(bank)/4, S10_amplitude(bank), fixed_wrap, fixed_truncate);							
							S10_amplitude(bank) <= S09_amplitude_presmooth(bank);

						End If;

					End If;
					If srun(S10) = '1' Then
						S11_amplitude(bank) <= S10_amplitude(bank);
						S11_SINE_out(bank)  <= S10_SINE_out(bank);
					End If;
					
					If srun(S11) = '1' Then
						S12_amplitude(bank) <= Std_logic_vector(S11_amplitude(bank));
						S12_sine_adjusted(bank) <= resize(S11_SINE_out(bank) * S11_amplitude(bank), S12_sine_adjusted(bank), fixed_wrap, fixed_round);
					End If;

				End If;
			End If;
		End Process;
	End Generate;

	sflow_i : Entity work.flow
		Port Map(
			clk => clk,
			rst => rst,

			in_ready => Open,
			in_valid => '1',
			out_ready => S17_READY,
			out_valid => Open,

			run => srun
		);

	-- sum process\\
	sumproc2 :
	Process (clk)
	Begin
		If rising_edge(clk) Then

            seed_rst <= '0';
			If rst = '0' Then
                
                if gain_wr = '1' then
                    if to_integer(unsigned(mm_wraddr)) = 0 then
                        GAIN_LEFT  <= sfixed(mm_wrdata_processbw);
                    else
                        GAIN_RIGHT <= sfixed(mm_wrdata_processbw);
                    end if;
                end if;
                
                If srun(S00) = '1' Then
                    S00_sadr <= S00_sadr + 1;
                    sadr(S01) <= Std_logic_vector(S00_sadr);
                    If signed(S00_sadr) = to_signed(-1, S00_sadr'length) Then
                        S01_increment <= E_INC(0);
                        seed_rst <= '1';
                    Else
                        S01_increment <= resize(S01_increment * to_ufixed(1.00057778951, 1, -PROCESS_BW + 2), S01_increment, fixed_wrap, fixed_truncate);
                    End If;
                End If;
                
				If srun(S01) = '1' Then
				    S02_phasenext <= ufixed(S01_phase);
				    S02_increment <= S01_increment;
					If unsigned(Sadr(S01)) = X"36F" Then
						--S02_TEST_phase <= ufixed(S01_phase(5));
					End If;
				End If;
				
				If srun(S02) = '1' Then
                    S03_phasenext <= Std_logic_vector(resize(S02_phasenext + S02_increment, S02_phasenext, fixed_wrap, fixed_truncate));

					-- test vector
					If unsigned(Sadr(S02)) = X"36F" Then
						S03_TEST_phase <= signed(S02_phase(5));
					End If;
				End If;
				If srun(S09) = '1' Then
					If unsigned(Sadr(S09)) = X"36F" Then
						S10_TEST_amplitude <= S09_amplitude(5);
					End If;
				End If;

				If srun(S10) = '1' Then
					-- test vector
					--If unsigned(Sadr(S10)) = X"36F" Then
					--	S12_TEST_SINE_out <= S10_SINE_out(5);
					--End If;
				End If;

				If srun(S12) = '1' Then
					If unsigned(Sadr(S12)) = X"36F" Then
						S13_TEST_sine_adjusted <= S12_sine_adjusted(5);
					End If;
					S13_BANK_0_1 <= resize(S12_sine_adjusted(0) + S12_sine_adjusted(1), S13_BANK_0_1, fixed_wrap, fixed_truncate);
					S13_BANK_2_3 <= resize(S12_sine_adjusted(2) + S12_sine_adjusted(3), S13_BANK_0_1, fixed_wrap, fixed_truncate);
					S13_BANK_4_5 <= resize(S12_sine_adjusted(4) + S12_sine_adjusted(5), S13_BANK_0_1, fixed_wrap, fixed_truncate);
					S13_BANK_6_7 <= resize(S12_sine_adjusted(6) + S12_sine_adjusted(7), S13_BANK_0_1, fixed_wrap, fixed_truncate);
					S13_BANK_8_9 <= resize(S12_sine_adjusted(8) + S12_sine_adjusted(9), S13_BANK_0_1, fixed_wrap, fixed_truncate);
				End If;

				If srun(S13) = '1' Then
					S14_BANK_0_1_2_3 <= resize(S13_BANK_0_1 + S13_BANK_2_3, S14_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
					S14_BANK_4_5_6_7 <= resize(S13_BANK_4_5 + S13_BANK_6_7, S14_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
					S14_BANK_8_9 <= resize(S13_BANK_8_9, S14_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
				End If;

				If srun(S14) = '1' Then
					S15_TOTAL <= resize(S14_BANK_0_1_2_3 + S14_BANK_4_5_6_7 + S14_BANK_8_9, S15_TOTAL, fixed_wrap, fixed_truncate);
				End If;

				If srun(S15) = '1' Then
					S16_TOTAL_left <= resize(S15_TOTAL* GAIN_LEFT , S15_TOTAL, fixed_wrap, fixed_truncate);
					S16_TOTAL_right<= resize(S15_TOTAL* GAIN_RIGHT, S15_TOTAL, fixed_wrap, fixed_truncate);
				End If;

				If S17_PCM_TREADY = '1' Then
					S17_PCM_TVALID_int <= '0';
				End If;

				If srun(S16) = '1' Then
					S17_sum_left  <= resize(S17_sum_left  + S16_TOTAL_left, S17_sum_left, fixed_wrap, fixed_round);
					S17_sum_right <= resize(S17_sum_right + S16_TOTAL_right, S17_sum_left, fixed_wrap, fixed_round);
					If unsigned(sadr(S15)) = SINESPERBANK - 1 Then
						S17_sum_left  <= resize(S16_TOTAL_left , S17_sum_left , fixed_wrap, fixed_round);
						S17_sum_right <= resize(S16_TOTAL_right, S17_sum_right, fixed_wrap, fixed_round);
						-- for now, mono output
						-- S17_PCM_TDATA   <= std_logic_vector(S17_sum_left(12 downto -3)) & std_logic_vector(S17_sum_left(12 downto -3)) ;
						S17_PCM_TDATA <= Std_logic_vector(S17_sum_left(10 Downto -13)) & Std_logic_vector(S17_sum_right(10 Downto -13));
						S17_PCM_TVALID_int <= '1';
					End If;
				End If;
			End If;
		End If;
	End Process;

End arch_imp;