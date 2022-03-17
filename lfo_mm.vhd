Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity lfo_mm Is
	Generic (
		PROCESS_BW : Integer := 25;
		NOTECOUNT  : Integer := 128;
		NOTECOUNTLOG2: Integer := 7;
		I2s_BITDEPTH : Integer := 24;
		PHASE_PRECISION : Integer := 32;
		CHANNEL_COUNT: Integer := 2
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		srun : In std_logic_vector;
        Z01_inc  : in std_logic_vector(PHASE_PRECISION-1 downto 0);
        op_select     : in std_logic;
        inc_wr    : in std_logic;
        gain_wr       : in std_logic;
        gainporta_wr  : in std_logic;
		Z01_fmmod: In Std_logic_vector;
		mm_wraddr     : In Std_logic_vector;
		mm_wrdata     : In Std_logic_vector;
        Z09_gain_finished : out std_logic;
        Z00_NoteIndex : in Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0) := (Others => '0');
		
        Z08_sine            : out sfixed(1 downto -PROCESS_BW+2);
        Z09_attenuated_out  : Out sfixed(1 downto -PROCESS_BW+2)
	);
End lfo_mm;

Architecture arch_imp Of lfo_mm Is

Constant CHAINLENGTH : integer := 6;
Type addrtype Is Array(Z01 To CHAINLENGTH) Of Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0);
Signal NoteIndex : addrtype := (Others => (Others => '0'));
Signal Z07_gain : std_logic_vector(PROCESS_BW-1 downto 0);
Signal Z08_sine_int : sfixed(1 downto -PROCESS_BW+2);
Signal Z08_gain : sfixed(1 downto -PROCESS_BW+2);
Signal mm_wrdata_processbw : std_logic_vector(PROCESS_BW-1 downto 0);
Signal Z01_increment_adj   : std_logic_vector(PROCESS_BW-1 downto 0);

Signal gain_wr_sel       : std_logic;
Signal gainporta_wr_sel  : std_logic;
Signal inc_wr_sel  : std_logic;
        
Begin
    Z08_sine <= Z08_sine_int;

    gain_wr_sel       <= gain_wr      and op_select;
    gainporta_wr_sel  <= gainporta_wr and op_select;
    inc_wr_sel    <= inc_wr   and op_select;

    mm_wrdata_processbw <= mm_wrdata(PROCESS_BW-1 downto 0);
    gainchaser : Entity work.chaser_mm
	Generic Map(
		COUNT     => NOTECOUNT,   
		LOG2COUNT => NOTECOUNTLOG2
	)
	Port Map(
		clk        => clk        ,
		rst        => rst        ,
		srun       => srun       ,
		
        target_wr  => gain_wr_sel  ,
        porta_wr   => gainporta_wr_sel   ,
        mm_wraddr  => mm_wraddr  ,
		mm_wrdata  => mm_wrdata_processbw  ,
		
        Z03_finished => Z09_gain_finished,
		
		Z00_rden   => srun(Z06)  ,
		Z00_addr   => NoteIndex(Z06),
		Z01_current=> Z07_gain
	);
    
    increment_adj : Entity work.simple_dual_one_clock
        Generic Map(
            DATA_WIDTH => PROCESS_BW,
            ADDR_WIDTH => NOTECOUNTLOG2
        )
        Port Map(
            clk => clk,
            wea => '1',
            wraddr  => mm_wraddr  ,
            wrdata  => mm_wrdata_processbw  ,
            wren => inc_wr_sel,
            rden => srun(Z00),
            rdaddr => Z00_NoteIndex,
            rddata => Z01_increment_adj
        );
			
    osc_i : Entity work.osc
	Port Map(
		clk        => clk        ,
		rst        => rst        ,
		srun       => srun       ,
		
		Z01_increment_adj=>Z01_increment_adj,
		Z01_fmmod => Z01_fmmod,
		Z01_increment => Z01_inc  ,
		
		Z00_addr    => Z00_NoteIndex,
		Z08_sine_out=> Z08_sine_int
	);
	
    -- sine process
    -- all output from ram
    sineproc :
    Process (clk)
    Begin
        If rising_edge(clk) Then

            If rst = '0' Then
                           
                addrloop :
                For i In Z02 To CHAINLENGTH Loop
                    If srun(i - 1) = '1' Then
                        NoteIndex(i) <= NoteIndex(i - 1);
                    End If;
                End Loop;

                If srun(Z00) = '1' Then
                    NoteIndex(Z01) <= Z00_NoteIndex;
                End If;

                If srun(Z07) = '1' Then
                    Z08_gain  <= sfixed(Z07_gain);
                End If;

                If srun(Z08) = '1' Then
                    Z09_attenuated_out  <= resize(Z08_sine_int*Z08_gain, 1, -PROCESS_BW+2, fixed_saturate, fixed_truncate);
                End If;

            End If;
        End If;
    End Process;
End arch_imp;