Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;
Use work.zconstants_pkg.All;
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity osc_mm Is
	Generic (
		PROCESS_BW : Integer := 25;
		VOICECOUNT  : Integer := 128;
		VOICECOUNTLOG2: Integer := 7;
		PHASE_PRECISION : Integer := 32;
		DEBUG_ON : String := "false";
		OPERATOR_NUMBER : INTEGER := 0
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		run : In std_logic_vector;
		CS      : in Std_logic;
        inc_wr      : in std_logic;
        incrate_wr   : in std_logic;
		
        env_wr       : in std_logic;
        envrate_wr  : in std_logic;
        Z10_env_finished  : out std_logic;
        Z10_inc_finished  : out std_logic;
        
		Z01_PitchLfo  : In sfixed;
		Z01_fmmod     : In sfixed;
		mm_addr     : In Std_logic_vector;
		mm_wrdata     : In Std_logic_vector;
        passthrough   : in STD_LOGIC;
        Z00_VoiceIndex : in Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		
        Z09_sine_postenv  : out sfixed(1 downto -PROCESS_BW+2)
	);
End osc_mm;

Architecture arch_imp Of osc_mm Is

Attribute mark_debug : String;
Type addrtype Is Array(Z01 To run'high) Of Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
Signal Z01_increment  : std_logic_vector(PHASE_PRECISION-1 downto 0);
Signal Z07_envelope : std_logic_vector(32-1 downto 0);
Signal Z07_envelope_trunc : std_logic_vector(PROCESS_BW-1 downto 0);
Signal Z08_envelope    : sfixed(1 downto -PROCESS_BW+2);
Signal Z08_sine_preenv : sfixed(1 downto -PROCESS_BW+2);
Signal Z09_sine_postenv_int : sfixed(1 downto -PROCESS_BW+2);
Signal Z08_sine_preenv_slv      : std_logic_vector(PROCESS_BW-1 downto 0);
Signal Z09_sine_postenv_int_slv : std_logic_vector(PROCESS_BW-1 downto 0);
Attribute mark_debug Of Z01_increment : Signal Is DEBUG_ON;
Attribute mark_debug Of Z07_envelope : Signal Is DEBUG_ON;
Attribute mark_debug Of Z07_envelope_trunc : Signal Is DEBUG_ON;
Attribute mark_debug Of Z08_sine_preenv_slv : Signal Is DEBUG_ON;
Attribute mark_debug Of Z09_sine_postenv_int_slv : Signal Is DEBUG_ON;
Signal mm_wrdata_processbw : std_logic_vector(PROCESS_BW-1 downto 0);

Signal Z01_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');
Signal Z02_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');
Signal Z03_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');
Signal Z04_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');
Signal Z05_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');
Signal Z06_VoiceIndex : Std_logic_vector(Z00_VoiceIndex'length - 1 Downto 0) := (Others => '0');

Signal Z02_PitchLFO  : sfixed(Z01_PitchLfo'high downto Z01_PitchLfo'low) := (others => '0');
Signal Z02_fmmod     : sfixed(Z01_fmmod'high downto Z01_fmmod'low) := (others => '0');
Signal Z03_fmmod_adj : sfixed(1 downto -Z01_increment'length+2);

Signal Z02_increment : signed(Z01_increment'high downto 0);

Signal Z04_inc_finished  : std_logic := '0';
Signal Z05_inc_finished  : std_logic := '0';
Signal Z06_inc_finished  : std_logic := '0';
Signal Z07_inc_finished  : std_logic := '0';
Signal Z08_inc_finished  : std_logic := '0';
Signal Z09_inc_finished  : std_logic := '0';
        
-- !!!!!!
Constant FMMOD_SCALE_FACTOR: integer := 3; 
Signal Z02_increment_sf : sfixed(1 + FMMOD_SCALE_FACTOR downto -Z01_increment'length +2 + FMMOD_SCALE_FACTOR);

Signal Z03_increment : sfixed(1 downto -PHASE_PRECISION +2);
Signal Z04_increment : sfixed(1 downto -PHASE_PRECISION +2);
Signal Z01_phase     : Std_logic_vector(Z01_increment'high downto 0);
Signal Z02_phase_signed : Signed(Z01_increment'high downto 0);
Signal Z02_phase     : sfixed(1 downto -Z01_increment'length+2);
Signal Z03_phase     : sfixed(1 downto -Z01_increment'length+2);
Signal Z04_phase     : sfixed(1 downto -Z01_increment'length+2);
Signal Z05_phase     : sfixed(1 downto -Z01_increment'length+2);
Signal Z06_phase     : Std_logic_vector(Z01_increment'high downto 0);

Signal Z02_run : std_logic_vector(run'high-Z02 downto 0);

Signal inc_wr_sel        : std_logic;
Signal incrate_wr_sel   : std_logic;

Signal mm_wrdata_phase : Std_logic_vector(PHASE_PRECISION - 1 Downto 0) := (Others => '0');
Signal mm_voiceno : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
	

Begin
    Z08_sine_preenv_slv      <= std_logic_vector(Z08_sine_preenv     );
    Z09_sine_postenv_int_slv <= std_logic_vector(Z09_sine_postenv_int);

	mm_wrdata_processbw <= mm_wrdata(PROCESS_BW - 1 Downto 0);
	mm_wrdata_phase <= mm_wrdata(PHASE_PRECISION - 1 Downto 0);
	mm_voiceno      <= mm_addr(VOICECOUNTLOG2 - 1 Downto 0);

    Z07_envelope_trunc <= Z07_envelope(Z07_envelope'high downto Z07_envelope'length - Z08_envelope'length );
    envelope_i : Entity work.chaser_mm
    Generic Map(
        COUNT     => VOICECOUNT,   
        LOG2COUNT => VOICECOUNTLOG2
    )
    Port Map(
        clk        => clk       ,
        rst        => rst       ,
        run        => run       ,
        
        target_wr  => env_wr  ,
        rate_wr    => envrate_wr   ,
        
        mm_addr    => mm_voiceno ,
        mm_wrdata  => mm_wrdata  ,
        mm_wrdata_rate  => mm_wrdata  ,
        
        Z04_finished => Z10_env_finished,
        
        Z00_rden   => run(Z06)  ,
        Z00_VoiceIndex   => Z06_VoiceIndex,
        Z01_current=> Z07_envelope 
    );

    inc_chaser : Entity work.chaser_mm
        Generic Map(
            COUNT     => VOICECOUNT,
            LOG2COUNT => VOICECOUNTLOG2
        )
        Port Map(
            clk => clk,
            rst => rst,
            run=> run,
            
            mm_addr => mm_voiceno,
            mm_wrdata => mm_wrdata,
            mm_wrdata_rate => mm_wrdata,
            
            Z00_rden => run(Z00),
            Z00_VoiceIndex => Z00_VoiceIndex,
            Z01_current => Z01_increment,
            Z04_finished => Z04_inc_finished, 
            target_wr => inc_wr_sel,
            rate_wr  => incrate_wr_sel
    
        );

    Z09_sine_postenv <= Z09_sine_postenv_int;

    inc_wr_sel       <= inc_wr     and CS;
    incrate_wr_sel   <= incrate_wr and CS;

    mm_wrdata_processbw <= mm_wrdata(PROCESS_BW-1 downto 0);
	
    sineproc :
    Process (clk)
    Begin
        If rising_edge(clk) Then
            If rst = '0' Then
            
                If run(Z00) = '1' Then
                    Z01_VoiceIndex <= Z00_VoiceIndex;
                End If;

                If run(Z01) = '1' Then
                    Z02_VoiceIndex <= Z01_VoiceIndex;  
                    Z02_increment <= resize(signed(Z01_increment), Z02_Phase'length); 
                    Z02_fmmod     <= Z01_fmmod;  
                    Z02_Phase     <= sfixed(Z01_Phase);
                    Z02_phase_signed <= signed(Z01_Phase);
                End If;
                If run(Z02) = '1' Then
                    Z03_fmmod_adj <= resize(Z02_fmmod * Z02_increment_sf, Z03_fmmod_adj, fixed_wrap, fixed_truncate);  

                    Z03_VoiceIndex <= Z02_VoiceIndex;    
                    Z03_increment <= sfixed(Z02_increment);
                    
                    -- reset phase to 0 if increment is 0  
                    if signed(Z02_increment) = 0 then
                        Z03_Phase <= (others => '0');
                    -- set phase to 1/2 if increment is -1
                    elsif signed(Z02_increment) = -2 then
                        Z03_Phase <= (others => '0');
                        Z03_Phase(Z03_Phase'high) <= '1';
                    elsif passthrough = '0' then
                        -- really, pitchlfo should be scaled to the increment
                        Z03_Phase <= resize(Z02_Phase + Z02_PitchLfo, Z03_Phase, fixed_wrap, fixed_truncate); 
                    else                        
                        Z03_Phase <= resize(Z02_Phase + to_sfixed(2.0**(Z02_Phase'low-1), Z03_Phase), Z03_Phase, fixed_wrap, fixed_truncate); 
                    end if;
                End If;
                If run(Z03) = '1' Then
                    if passthrough = '1' then
                        Z04_increment   <= to_sfixed(2.0**(Z04_increment'low), Z04_increment );
                    else
                        Z04_increment   <= resize(Z03_increment + Z03_fmmod_adj, Z04_increment, fixed_wrap, fixed_truncate);
                    end if;
                    
                    Z04_VoiceIndex  <= Z03_VoiceIndex;     
                    Z04_Phase       <= Z03_phase;        

                End If;
                If run(Z04) = '1' Then
                    Z05_inc_finished <= Z04_inc_finished;
                    Z05_VoiceIndex  <= Z04_VoiceIndex;    
                    Z05_Phase <= resize(Z04_Phase + Z04_increment, Z04_Phase, fixed_wrap, fixed_truncate); 
                End If;
                If run(Z05) = '1' Then
                    Z06_inc_finished <= Z05_inc_finished;
                    Z06_VoiceIndex  <= Z05_VoiceIndex;      
                    Z06_Phase <= std_logic_vector(Z05_phase);         
                End If;
                
                If run(Z06) = '1' Then
                    Z07_inc_finished <= Z06_inc_finished;       
                End If;
            
                If run(Z07) = '1' Then
                    Z08_inc_finished <= Z07_inc_finished;       
                    if passthrough = '0' then
                        Z08_envelope <= sfixed(Z07_envelope_trunc);
                    else
                        Z08_envelope <= to_sfixed(1.0, Z08_envelope);
                    end if;
                End If;
                
                If run(Z08) = '1' Then
                    Z09_inc_finished <= Z08_inc_finished;   
                    Z09_sine_postenv_int <= resize(Z08_sine_preenv*Z08_envelope, Z08_sine_preenv, fixed_wrap, fixed_truncate);
                End If;
                
                If run(Z09) = '1' Then
                    Z10_inc_finished <= Z09_inc_finished;   
                End If;
                
            End If;
        End If;
    End Process;
    
    Z02_increment_sf <= sfixed(Z02_increment);
    Z02_run <= run(run'high downto Z02);
    phase_ram : Entity work.simple_dual_one_clock
        Port Map(
            clk => clk,
            wea => '1',
            wraddr => Z06_VoiceIndex,
            wrdata => Z06_phase,
            wren   => run(Z06),
            rden   => run(Z00),
            rdaddr => Z00_VoiceIndex,
            rddata => Z01_Phase
        );
    
    i_sine_lookup : Entity work.sine_lookup
        Port Map(
            clk => clk,
            rst => rst,
            passthrough  => passthrough,
            Z00_PHASE    => Z02_phase_signed,
            Z06_SINE_out => Z08_sine_preenv,
            run => Z02_run
        );

End arch_imp;
