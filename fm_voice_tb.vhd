Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Library work;
Use work.spectral_pkg.All;

-- entity declaration for your testbench.Dont declare any ports here
Entity fm_voice_tb Is
    Generic (
        phase_bw: integer := 32;
        VOICECOUNT    : integer := 8;
        VOICECOUNTLOG2: integer := 3;
        OPERATOR_COUNT: integer:= 8;
        OPERATOR_COUNT_LOG2: integer:= 3;
        process_bw: integer := 18
    );
End fm_voice_tb;

Architecture behavior Of fm_voice_tb Is

    signal clk                  : Std_logic := '0';
    signal rst                  : Std_logic := '1';
    
    signal testphase            : integer := 0;
    signal wren_array           : Std_logic_vector(127 Downto 0) := (Others => '0');
    
    signal mm_addr         : Std_logic_vector(31 Downto 0) := (Others => '0');
    signal mm_wrdata            : Std_logic_vector(31 Downto 0) := (Others => '0');
    signal mm_voiceno0          : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0) := (Others => '0');
    signal mm_voiceno1          : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0) := (Others => '0');
    signal mm_voiceno2          : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0) := (Others => '0');
    signal mm_wrdata_processbw  : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
    
    signal mm_opno_onehot       : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0) := (Others => '0');
    
    signal Z13_env_finished     : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);
    signal sounding_slv     : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0) := (others=>'0');
    
    signal passthrough          : Std_logic := '0';
    
    signal Z14_voiceamp_ready   : Std_logic := '1';
    signal Z14_voiceamp_data    : sfixed(1 Downto -PROCESS_BW - OPERATOR_COUNT_LOG2 + 2);
    signal Z14_voiceamp_valid   : Std_logic;
    signal Z14_voiceIndex       : Std_logic_vector(VOICECOUNTLOG2 - 1 Downto 0);
		
    signal irqueue_in_data  : STD_LOGIC_VECTOR(VOICECOUNTLOG2+OPERATOR_COUNT*2 - 1 Downto 0);
    signal irqueue_in_ready : std_logic := '1';
    signal irqueue_in_valid : std_logic;

Begin
    mm_wrdata_processbw <= mm_wrdata(PROCESS_BW-1 downto 0);
    -- Instantiate the Unit Under Test (UUT)
    fm_voice_i: entity work.fm_voice
    Generic Map(
        VOICECOUNT           => VOICECOUNT,
        VOICECOUNTLOG2       => VOICECOUNTLOG2  ,
        PROCESS_BW          => PROCESS_BW ,
        PHASE_PRECISION     => phase_bw ,
        OPERATOR_COUNT      => OPERATOR_COUNT  ,
        OPERATOR_COUNT_LOG2 => OPERATOR_COUNT_LOG2  ,
        FMSRC_COUNT_LOG2    => 4
    )
    Port Map(
        clk                  => clk                  ,
        rst                  => rst                  ,
        
        wren_array           => wren_array           ,
        
        mm_addr         => mm_addr         ,
        mm_wrdata            => mm_wrdata            ,
        mm_voiceno0          => mm_voiceno0          ,
        mm_voiceno1          => mm_voiceno1          ,
        mm_voiceno2          => mm_voiceno2          ,
        mm_wrdata_processbw  => mm_wrdata_processbw  ,
        
        mm_opno_onehot       => mm_opno_onehot       ,
        
        passthrough          => passthrough          ,
        
        Z14_voiceamp_ready   => Z14_voiceamp_ready   ,
        Z14_voiceamp_data    => Z14_voiceamp_data    ,
        Z14_voiceamp_valid   => Z14_voiceamp_valid   ,
        Z14_voiceIndex       => Z14_voiceIndex       ,
		
        irqueue_in_data  => irqueue_in_data ,
        irqueue_in_ready => irqueue_in_ready,
        irqueue_in_valid => irqueue_in_valid

    );

    clk <= not clk after 10ns; 
    
    voicetest0 : Process(clk)
    Begin
        If rising_edge(clk) Then
            If rst = '0' Then
                mm_addr <= std_logic_vector(unsigned(mm_addr) + 1);
            end if;
        end if;
    End Process;
    

    voicetest : Process
        procedure sendcommand(commandno: in INTEGER; voiceno: in integer; opno : in integer; value: in Integer) is
        begin
            mm_opno_onehot       <= (others=>'0');
            mm_opno_onehot(opno) <= '1';
            wren_array <= (others=>'0'); wren_array(commandno) <= '1';
            mm_wrdata  <= std_logic_vector(to_unsigned(value, 32)); -- Reasonably quick env rate
            wait until rising_edge(clk);
            wren_array <= (others=>'0');
        end procedure;
        
        procedure waitperiod(period: in INTEGER) is
        begin
            wren_array <= (others=>'0'); 
            mm_opno_onehot       <= (others=>'0');
            mm_wrdata  <= std_logic_vector(to_unsigned(0, 32));
            for ii in 0 to period loop
            wait until rising_edge(clk);
            end loop;
            testphase  <= testphase + 1;
        end procedure;
        
        procedure VoiceSetup(
        am_algo        : in INTEGER:= 0    ;
        fbsrc          : in INTEGER:= 0    ;
        fbgain         : in INTEGER:= 0   
        ) is
        begin
            sendcommand(cmd_am_algo       , 0, 0, am_algo        );
            sendcommand(cmd_fbsrc         , 0, 0, fbsrc          );
            sendcommand(cmd_fbgain        , 0, 0, fbgain         );
                       
        end procedure;
        
        procedure OpSetup(
        opno: in INTEGER; 
        sounding       : in std_logic:= '1';
        env            : in INTEGER:= 2**30;
        env_rate       : in INTEGER:= 2**26;
        increment      : in INTEGER:= 2**26;
        increment_rate : in INTEGER:= 2**22
        ) is
        begin
            sounding_slv(opno) <= sounding;
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            sendcommand(cmd_sounding      , 0, opno, to_integer(unsigned(sounding_slv)));
            sendcommand(cmd_env           , 0, opno, env            ); -- Full env
            sendcommand(cmd_env_rate      , 0, opno, env_rate       );
            sendcommand(cmd_increment     , 0, opno, increment      );
            sendcommand(cmd_increment_rate, 0, opno, increment_rate );
                       
        end procedure;
    Begin
        rst <= '0';
        waitperiod(10000);
        -- section 1        
        sendcommand(cmd_fm_algo, 0, 0, 16#77777777#); -- HEX for Integers (smh)
        
        wren_array <= (others=>'0'); 
        OpSetup(0);
        
        waitperiod(10000);
        -- section 2        
        
        sendcommand(cmd_fbgain,  0, 0, 2**15); -- FB gain passthrough
        sendcommand(cmd_fm_algo, 0, 0, 16#77777776#); -- All 7's - Null
        
        waitperiod(10000);
        
        -- do tremolo
        OpSetup(6, sounding => '0', increment => 2**23);
        
        waitperiod(10000);
        
        -- after some time, try an fm modulation
        OpSetup(6, sounding => '0', env => 0);
        OpSetup(1,increment => 2**24);
        sendcommand(cmd_fbgain, 0, 0, 0);
        sendcommand(cmd_fm_algo, 0, 0, 16#77777771#); -- All 7's - Null
        
        wren_array <= (others=>'0'); 
        
        
        wait;
    End Process;

End;