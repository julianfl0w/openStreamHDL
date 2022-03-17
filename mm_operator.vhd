----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 3/2020
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE ieee.math_real.ALL;

LIBRARY work;
USE work.spectral_pkg.ALL;

LIBRARY IEEE_PROPOSED;
USE IEEE_PROPOSED.FIXED_PKG.ALL;
LIBRARY UNISIM;
USE UNISIM.vcomponents.ALL;

LIBRARY UNIMACRO;
USE UNIMACRO.vcomponents.ALL;
LIBRARY work;
USE work.spectral_pkg.ALL;
Use work.zconstants_pkg.All;
LIBRARY ieee_proposed;
USE ieee_proposed.fixed_pkg.ALL;
USE ieee_proposed.fixed_float_types.ALL;

ENTITY mm_operator IS
	GENERIC (
		VOICECOUNT           : INTEGER := 512;
		VOICECOUNTLOG2       : INTEGER := 9;
		PROCESS_BW          : INTEGER := 18;
		OPERATOR_COUNT      : INTEGER := 8;
		OPERATOR_COUNT_LOG2 : INTEGER := 3;
		DEBUG_ON : String := "false";
		OPERATOR_NUMBER     : INTEGER := 0
	);
	PORT (
		clk          : IN STD_LOGIC;
		rst          : IN STD_LOGIC;
        run          : in std_logic_vector;
		
        env_wr       : in std_logic;
        envrate_wr   : in std_logic;
        Z13_env_finished  : out std_logic;
        Z13_inc_finished  : out std_logic;
        
        wren_array  : in STD_LOGIC_VECTOR;
        mm_addr   : in STD_LOGIC_VECTOR(31 DOWNTO 0);
        mm_wrdata   : in STD_LOGIC_VECTOR(31 DOWNTO 0);
        mm_wrdata_processbw : in STD_LOGIC_VECTOR(PROCESS_BW - 1 DOWNTO 0);
	
	    Z01_VoiceIndex : in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0);
	    Z02_VoiceIndex : in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0);
	    Z03_VoiceIndex : in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0);
	    Z09_VoiceIndex : in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0);
	    Z12_VoiceIndex : in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0);
        
        Z04_pitchlfo : in sfixed;
        
	    Z02_fm_src_index  :  in unsigned;
	    Z02_am_src_index  :  in unsigned;
	    
        Z02_operator_output : out sfixed(1 Downto -PROCESS_BW + 2);
        Z02_operators : in OPERATOR_PROCESS;
        passthrough : in STD_LOGIC;
	    
        Z02_fb_in  : in  sfixed(1 Downto -PROCESS_BW + 2); 
        
        Z05_opout_data : out sfixed(1 Downto -PROCESS_BW + 2);
        	
        cs   : in STD_LOGIC;
	    mm_voiceno :  in STD_LOGIC_VECTOR(VOICECOUNTLOG2 - 1 DOWNTO 0)

	);

END mm_operator;

ARCHITECTURE arch_imp OF mm_operator IS

	SIGNAL Z02_operator_output_sf  : sfixed(1 Downto -PROCESS_BW + 2);
	SIGNAL Z02_operator_output_slv : Std_logic_vector(PROCESS_BW - 1 Downto 0);

	SIGNAL shiftamount : INTEGER := 0;

	SIGNAL rst_delay : STD_LOGIC_VECTOR(20 DOWNTO 0) := (OTHERS => '0');
	           
    SIGNAL Z03_run : Std_logic_vector(run'high - Z03 Downto 0);
	SIGNAL Z03_ammod_muxd : sfixed(1 Downto -PROCESS_BW + 2); 
	SIGNAL Z04_ammod_muxd : sfixed(1 Downto -PROCESS_BW + 2); 

	SIGNAL Z04_output : sfixed(1 Downto -PROCESS_BW + 2);
	
	SIGNAL Z02_feedback : STD_LOGIC_VECTOR(PROCESS_BW - 1 DOWNTO 0) := (OTHERS => '0');
    Signal Z03_fmmod : sfixed(1 Downto -PROCESS_BW + 2);
    Signal Z03_fmmod_additional : sfixed(1 Downto -PROCESS_BW + 2);
    Signal Z03_outputlast : sfixed(1 Downto -PROCESS_BW + 2);
    Signal Z04_fmmod : sfixed(1 Downto -PROCESS_BW + 2);

	SIGNAL Z12_sine_postenv : sfixed(1 Downto -PROCESS_BW + 2);
	SIGNAL Z12_sine_postenv_slv : STD_LOGIC_VECTOR(PROCESS_BW - 1 downto 0);
	
BEGIN

    Z03_run <= RUN(run'high downto Z03);
    Z12_sine_postenv_slv <= std_logic_vector(Z12_sine_postenv);
    Z02_operator_output_sf <= sfixed(Z02_operator_output_slv);
    Z02_operator_output <= Z02_operator_output_sf;
    
   output_wraparound : ENTITY work.simple_dual_one_clock
       PORT MAP(
           clk => clk,
           wea => '1',
           wraddr => Z12_VoiceIndex,
           wrdata => Z12_sine_postenv_slv,
           wren => run(Z12),
           rden => run(Z01),
           rdaddr => Z01_VoiceIndex,
           rddata => Z02_operator_output_slv
       );

    osc_mm_i : ENTITY work.osc_mm
        GENERIC MAP(
            VOICECOUNT => VOICECOUNT,
            VOICECOUNTLOG2 => VOICECOUNTLOG2,
            PROCESS_BW => PROCESS_BW,
            OPERATOR_NUMBER => OPERATOR_NUMBER,
            DEBUG_ON => DEBUG_ON
        )
        PORT MAP(
            clk => clk,
            rst => rst,
            run => Z03_run,
            CS => cs,

            env_wr      => env_wr      , 
            envrate_wr => envrate_wr , 
        
            passthrough => passthrough,

            Z01_PitchLfo => Z04_pitchlfo,
            Z01_fmmod    => Z04_fmmod,
            
            Z10_env_finished => Z13_env_finished,
            Z10_inc_finished => Z13_inc_finished,
            inc_wr      => wren_array(cmd_increment),
            incrate_wr => wren_array(cmd_increment_rate),
            
            mm_addr => mm_voiceno,
            mm_wrdata => mm_wrdata,
            Z00_VoiceIndex => Z03_VoiceIndex,
            Z09_sine_postenv => Z12_sine_postenv
        );
    opproc :
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN

            IF rst = '0' THEN
                IF run(Z02) = '1' then
                    -- implement "anti-hunting" feedback stabilization
                        
                    Z03_outputlast <= Z02_operator_output_sf;
                    Z03_fmmod_additional <= (others=>'0');
                    -- vibrato and tremolo env is not feedbackable
                    if Z02_fm_src_index = 7 or OPERATOR_NUMBER = 7  or OPERATOR_NUMBER = 6 then
                        Z03_fmmod <= (others=>'0');
                    -- value of 6 indicates feedback recipient
                    elsif Z02_fm_src_index = 6 then
                        Z03_fmmod <= Z02_fb_in;
                    -- or they might be driven by a modulator
                    elsif Z02_fm_src_index < 6 then
                        Z03_fmmod <= Z02_operators(to_integer(Z02_fm_src_index));
                    -- they might be driven by several modulators
                    -- 8 is (5 + 6)
                    elsif Z02_fm_src_index = 8 then
                        Z03_fmmod <= resize(Z02_operators(5) + Z02_operators(6), Z03_fmmod, fixed_wrap, fixed_truncate);
                    -- 9 is (4 + 5)
                    elsif Z02_fm_src_index = 9 then
                        Z03_fmmod <= resize(Z02_operators(4) + Z02_operators(5), Z03_fmmod, fixed_wrap, fixed_truncate);
                    -- 10 is (4 + 5 + 6)
                    elsif Z02_fm_src_index = 10 then
                        Z03_fmmod <= resize(Z02_operators(5) + Z02_operators(6), Z03_fmmod, fixed_wrap, fixed_truncate);
                        Z03_fmmod_additional <= Z02_operators(4);
                    -- 11 is (2 + 3 + 5)
                    elsif Z02_fm_src_index = 11 then
                        Z03_fmmod <= resize(Z02_operators(2) + Z02_operators(3), Z03_fmmod, fixed_wrap, fixed_truncate);
                        Z03_fmmod_additional <= Z02_operators(5);
                    -- 12 is (2 + 3 + 4)
                    elsif Z02_fm_src_index = 12 then
                        Z03_fmmod <= resize(Z02_operators(2) + Z02_operators(3), Z03_fmmod, fixed_wrap, fixed_truncate);
                        Z03_fmmod_additional <= Z02_operators(4);
                    end if;
                    
                    IF Z02_am_src_index /= 0 THEN -- idgaf
                        Z03_ammod_muxd <= Z02_operators(to_integer(Z02_am_src_index));
                    ELSE
                        Z03_ammod_muxd <= to_sfixed(1.0, Z03_ammod_muxd);
                    END IF;
                end if;
                
                IF run(Z03) = '1' then
                    Z04_ammod_muxd <= Z03_ammod_muxd;
                    Z04_fmmod      <= resize(Z03_fmmod + Z03_fmmod_additional, Z04_fmmod, fixed_wrap, fixed_truncate);
                    Z04_output <= Z03_outputlast;
                end if;
				
                IF run(Z04) = '1' THEN						
                   Z05_opout_data <= resize(Z04_output * Z04_ammod_muxd, Z04_ammod_muxd, fixed_saturate, fixed_truncate); -- apply mod reduction here
                END IF;

            END IF;
        END IF;
    END PROCESS;

END arch_imp;
