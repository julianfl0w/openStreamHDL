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

Entity spectral_engine Is
	Generic (
		USE_MLMM : Integer := 1;
		NOTECOUNT : Integer := 512;
		NOTECOUNTLOG2 : Integer := 9;
		PROCESS_BW : Integer := 18;
		CHANNEL_COUNT : Integer := 2;
		VOLUMEPRECISION : Integer := 16;
		I2S_BITDEPTH : Integer := 24;
		PHASE_PRECISION : Integer := 32;
		CYCLE_BW : Integer := 3;
		LFO_COUNT : Integer := 2;
		OPERATOR_COUNT : Integer := 8;
		OPERATOR_COUNT_LOG2 : Integer := 3;
		SINESPERBANK_voiceaddrBW : Integer := 10
	);
	Port (
		sysclk : In Std_logic;
		rstin : In Std_logic;

		-- SPI SLAVE INTERFACE
		SPI_SCLK : In Std_logic; -- SPI clock
		SPI_CS_N : In Std_logic; -- SPI chip select, active in low
		SPI_MOSI : In Std_logic_vector(0 Downto 0); -- SPI serial data from master to slave
		SPI_MISO : Out Std_logic_vector(0 Downto 0); -- SPI serial data from slave to master

		i2s_bclk : Out Std_logic;
		i2s_mclk : Out Std_logic;
		i2s_lrclk : Out Std_logic := '1';
		i2s_dacsd : Out Std_logic := '0';
		i2s_adcsd : In Std_logic;
		
        irqueue_out_valid : out std_logic;
        audio_out_valid   : out std_logic := '0';

		btn : In Std_logic_vector(1 Downto 0) := (Others => '0');
		led : Out Std_logic_vector(1 Downto 0) := (Others => '0');
		led0_b : Out Std_logic := '1';
		led0_g : Out Std_logic := '1';
		led0_r : Out Std_logic := '1';

		halt : Out Std_logic := '1'
	);

End spectral_engine;

Architecture arch_imp Of spectral_engine Is

	Signal i2s_lrclk_i : Std_logic := '1';
	Signal i2s_dacsd_i : Std_logic := '0';
	Signal sysclk_bufg : Std_logic; -- SPI clock
	Signal SPI_SCLK_bufg : Std_logic; -- SPI clock

	Attribute mark_debug : String;

	Signal fbclk : Std_logic := '1';
	Signal plllock : Std_logic := '1';
	Signal clk_unbuffd : Std_logic := '1';
	Signal clk : Std_logic := '1';
	Signal rst : Std_logic := '1';
	Signal i2s_mclk_int : Std_logic := '1';
	Signal clk_200 : Std_logic := '1';

	Signal env_clkdiv : Integer := 0;

	Constant COUNTER_WIDTH : Integer := 32;
	Signal led_counter : unsigned(COUNTER_WIDTH - 1 Downto 0) := (Others => '0');
	Signal soft_rst_hist : Std_logic_vector(10 downto 0) := (Others => '0');
	signal soft_rst : std_logic;
	Signal sclk : Std_logic := '1';

	Type spi2mm_statetype Is (ADDR, DATA);
	Signal spi2mm_state : spi2mm_statetype := ADDR;
	Signal spi2mm_state_last : spi2mm_statetype := ADDR;
	Signal spi2mm_state_lastrcv : spi2mm_statetype := ADDR;
	Attribute mark_debug Of spi2mm_state : Signal Is "true";
	Attribute mark_debug Of spi2mm_state_last : Signal Is "true";
	Signal statechange : Std_logic;

	Signal SPI_RX_DATA : Std_logic_vector(31 Downto 0) := (Others => '0'); -- output data from SPI master
	Signal SPI_RX_VALID : Std_logic := '0'; -- when DOUT_VALID = 1, output data are valid
	Signal SPI_RX_READY : Std_logic := '0';
	Attribute mark_debug Of SPI_RX_DATA : Signal Is "true";
	Attribute mark_debug Of SPI_RX_VALID : Signal Is "true";
	Attribute mark_debug Of SPI_RX_READY : Signal Is "true";

	Signal SPI_TX_DATA : Std_logic_vector(31 Downto 0) := (Others => '0'); -- output data from SPI master
	Signal SPI_TX_VALID : Std_logic := '1'; -- when DOUT_VALID = 1, output data are valid
	Signal SPI_TX_READY : Std_logic := '0';
	Signal SPI_TX_GATED_DATA : Std_logic_vector(31 Downto 0) := (Others => '0'); -- output data from SPI master
	Signal SPI_TX_GATED_VALID : Std_logic := '0'; -- when DOUT_VALID = 1, output data are valid
	Signal SPI_TX_GATED_READY : Std_logic := '0';
	
	Signal TX_AMOUNT_DATA : integer := 0; -- output data from SPI master
	Signal TX_AMOUNT_VALID : Std_logic := '0'; -- when DOUT_VALID = 1, output data are valid
	Signal TX_AMOUNT_READY : Std_logic := '0';
    Signal SPI_TX_Enable : Std_logic := '0';
			
	Signal I2SOUTFIFO_VALID : Std_logic := '0';
	Signal I2SOUTFIFO_READY : Std_logic := '1';
	Signal I2SOUTFIFO_DATA : Std_logic_vector(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');
	Signal I2SOUTFIFO_DATA_LAST : unsigned(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');
	Signal I2SOUTFIFO_FAULT : Std_logic := '0';


	Signal sclk_sel : Std_logic := '0';

	Signal S02_channel_VALID_and_not_FLUSHSPI : Std_logic;

	Signal Z13_env_finished : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0);
	Attribute mark_debug Of Z13_env_finished : Signal Is "true";
	
	Signal mm_opno_onehot : Std_logic_vector(OPERATOR_COUNT - 1 Downto 0) := (Others => '0');
	Signal mm_voiceinc_mode : Std_logic;

	Signal I2S_RX_VALID : Std_logic;
	Signal I2S_RX_READY : Std_logic := '1';
	Signal I2S_RX_DATA : Std_logic_vector(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');

	Signal wren_array : Std_logic_vector(127 Downto 0) := (Others => '0');
    Signal increment_wr : Std_logic;
	Attribute mark_debug Of increment_wr : Signal Is "true";
	Signal i2s_begin : Std_logic;
	Signal FLUSHSPI : Std_logic := '1';
	Signal mm_voiceaddr : Std_logic_vector(31 Downto 0) := (Others => '0');
	Signal mm_paramnum : Integer := 0;
	Signal mm_wrdata : Std_logic_vector(31 Downto 0) := (Others => '0');
	Signal mm_wrdata_processbw : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal Z09_PitchLfo : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_algorithm : Std_logic_vector(OPERATOR_COUNT * OPERATOR_COUNT_LOG2 - 1 Downto 0) := (Others => '0');
	--Attribute mark_debug Of mm_wrdata : Signal Is "true";


	Signal srun : Std_logic_vector(S01 Downto S00) := (Others => '0');
	
	Signal passthrough : Std_logic := '0';
	Signal shiftamount : Integer := 0;

	Signal mm_voiceno0 : Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0);
	Signal mm_voiceno1 : Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0);
	Signal mm_voiceno2 : Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0);

	Signal rst_delay : Std_logic_vector(20 Downto 0) := (Others => '0');
	Signal channelgain_wr : Std_logic_vector(CHANNEL_COUNT - 1 Downto 0) := (Others => '0');

	Signal voice_amp_data_slv : std_logic_vector(I2S_BITDEPTH - 1 downto 0) := (others=>'0');
	Signal voice_amp_data : sfixed(1 Downto -I2S_BITDEPTH + 2);
	Signal voice_amp_ready : std_logic_vector(CHANNEL_COUNT-1 downto 0);
	Signal voice_amp_valid : std_logic; 
	Signal voice_amp_index : Std_logic_vector(NOTECOUNTLOG2 - 1 Downto 0);
	Attribute mark_debug Of voice_amp_index : Signal Is "true";
	
	Type Channel_I2S_Process Is Array (0 To CHANNEL_COUNT - 1) Of sfixed(1 Downto -I2S_BITDEPTH + 2);
	Type Channel_I2S_Process_SLV Is Array (0 To CHANNEL_COUNT - 1) Of std_logic_vector(I2S_BITDEPTH - 1 downto 0);
	Type Channel_I2S_Process_sfixed Is Array (0 To CHANNEL_COUNT - 1) Of sfixed(1 Downto -I2S_BITDEPTH + 2);
	Type Channel_I2S_Process_signed Is Array (0 To CHANNEL_COUNT - 1) Of signed(I2S_BITDEPTH - 1 downto 0);
	Signal S00_channel_data  : Channel_I2S_Process;
    Signal channelpostgain_data  : Channel_I2S_Process;
	Signal channelpostgain_ready : std_logic_vector(CHANNEL_COUNT-1 downto 0);
	Signal channelpostgain_valid : std_logic_vector(CHANNEL_COUNT-1 downto 0);
	
    Signal S00_channel_data_signed  : Channel_I2S_Process_signed;
	Signal S00_channel_ready : std_logic;
	Signal S00_channel_valid : std_logic_vector(CHANNEL_COUNT-1 downto 0);
	
    Signal S01_channel_shifted_signed  : Channel_I2S_Process_signed;	
    Signal S02_channel_data  : STD_LOGIC_VECTOR(I2s_BITDEPTH*CHANNEL_COUNT - 1 Downto 0);
	Signal S02_channel_ready : std_logic;
	Signal S02_channel_valid : std_logic;
    Signal S02_channel_data_last  : unsigned(I2s_BITDEPTH*CHANNEL_COUNT - 1 Downto 0);
	Signal S02_channel_fault : std_logic;
	
    Signal irqueue_in_data  : STD_LOGIC_VECTOR(NOTECOUNTLOG2+OPERATOR_COUNT - 1 Downto 0);
	Signal irqueue_in_ready : std_logic;
	Signal irqueue_in_valid : std_logic;
    Signal irqueue_out_data  : STD_LOGIC_VECTOR(NOTECOUNTLOG2+OPERATOR_COUNT - 1 Downto 0);
	Signal irqueue_out_ready : std_logic := '0';
	Signal irqueue_out_valid_int : std_logic := '0';
	Signal audio_out_ready : std_logic := '0';
	Signal tx_stream_select : integer := 0;
    Signal null_stream_ready : std_logic := '0';
	
	Signal sclk_hold_pregate : Std_logic;
	Signal sclk_hold         : Std_logic;
	Signal sclk_not         : Std_logic;
    attribute IODELAY_GROUP : STRING;
	Signal delay_rdy : Std_logic;
    attribute IODELAY_GROUP of IDELAYE2_inst:   label is "iodelay_group_name";
    attribute IODELAY_GROUP of IDELAYCTRL_inst: label is "iodelay_group_name";
	--Attribute mark_debug Of S02_channel_data : Signal Is "true";
	--Attribute mark_debug Of S00_channel_data_signed : Signal Is "true";
	--Attribute mark_debug Of voice_amp_data_slv : Signal Is "true";
	--Attribute mark_debug Of mm_voiceno0 : Signal Is "true";
	--Attribute mark_debug Of mm_voiceinc_mode : Signal Is "true";
	--Attribute mark_debug Of I2SOUTFIFO_DATA : Signal Is "true";
	--Attribute mark_debug Of I2SOUTFIFO_FAULT : Signal Is "true";
	--Attribute mark_debug Of mm_opno_onehot : Signal Is "true";
Begin
    sclk_not <= not sclk;
    irqueue_out_valid <= irqueue_out_valid_int;
    increment_wr <= wren_array(cmd_increment);
	--S02_channel_BACKPRESSURE <= not S02_channel_VALID;
	S02_channel_VALID_and_not_FLUSHSPI <= S02_channel_READY And Not FLUSHSPI;
	i2s_mclk <= i2s_mclk_int;

	statechange <= '1' When spi2mm_state /= spi2mm_state_last Else '0';
	i2s_lrclk <= i2s_lrclk_i;
	i2s_dacsd <= i2s_dacsd_i;
    
	rst <= rstin Or Not plllock Or soft_rst;
	halt <= rst;
	passthrugen :
	If USE_MLMM = 0 Generate
		clk <= sysclk;
	End Generate;

	-- use clk to init rams, then switch to sclk for spi
	BUFGMUX_inst : BUFGMUX
	Port Map(
		O => sclk, -- 1-bit output: Clock output
		I0 => SPI_SCLK_bufg, -- 1-bit input: Clock input (S=0)
		I1 => clk, -- 1-bit input: Clock input (S=1)
		S => sclk_sel -- 1-bit input: Clock select
	);
	
	-- use clk to init rams, then switch to sclk for spi
	BUFGMUX_hold_inst : BUFGMUX
	Port Map(
		O => sclk_hold, -- 1-bit output: Clock output
		I0 => sclk_hold_pregate, -- 1-bit input: Clock input (S=0)
		I1 => clk, -- 1-bit input: Clock input (S=1)
		S => sclk_sel -- 1-bit input: Clock select
	);

	--clk <= clk_unbuffd;
	BUFG_inst : BUFG
	Port Map(
		O => sysclk_bufg, -- 1-bit output: Clock output
		I => sysclk -- 1-bit input: Clock input
	);

	--clk <= clk_unbuffd;
	BUFG_inst_2 : BUFG
	Port Map(
		O => SPI_SCLK_bufg, -- 1-bit output: Clock output
		I => SPI_SCLK -- 1-bit input: Clock input
	);

	mlmmgen :
	If USE_MLMM = 1 Generate

		--clk <= clk_unbuffd;
		BUFG_inst : BUFG
		Port Map(
			O => clk, -- 1-bit output: Clock output
			I => clk_unbuffd -- 1-bit input: Clock input
		);

		MMCME2_BASE_inst : MMCME2_BASE
		Generic Map(
			BANDWIDTH => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
			CLKFBOUT_MULT_F => 58.375, -- Multiply value for all CLKOUT (2.000-64.000).
			CLKFBOUT_PHASE => 0.0, -- Phase offset in degrees of CLKFB (-360.000-360.000).
			CLKIN1_PERIOD => 83.3333333, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
			-- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
			CLKOUT1_DIVIDE => 1,
			CLKOUT2_DIVIDE => 19,
			CLKOUT3_DIVIDE => 7,
			CLKOUT4_DIVIDE => 1,
			CLKOUT5_DIVIDE => 1,
			CLKOUT6_DIVIDE => 1,
			CLKOUT0_DIVIDE_F => 3.5, -- Divide amount for CLKOUT0 (1.000-128.000).
			-- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
			CLKOUT0_DUTY_CYCLE => 0.5,
			CLKOUT1_DUTY_CYCLE => 0.5,
			CLKOUT2_DUTY_CYCLE => 0.5,
			CLKOUT3_DUTY_CYCLE => 0.5,
			CLKOUT4_DUTY_CYCLE => 0.5,
			CLKOUT5_DUTY_CYCLE => 0.5,
			CLKOUT6_DUTY_CYCLE => 0.5,
			-- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
			CLKOUT0_PHASE => 0.0,
			CLKOUT1_PHASE => 0.0,
			CLKOUT2_PHASE => 0.0,
			CLKOUT3_PHASE => 0.0,
			CLKOUT4_PHASE => 0.0,
			CLKOUT5_PHASE => 0.0,
			CLKOUT6_PHASE => 0.0,
			CLKOUT4_CASCADE => FALSE, -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
			DIVCLK_DIVIDE => 1, -- Master division value (1-106)
			REF_JITTER1 => 0.0, -- Reference input jitter in UI (0.000-0.999).
			STARTUP_WAIT => FALSE -- Delays DONE until MMCM is locked (FALSE, TRUE)
		)
		Port Map(
			-- Clock Outputs: 1-bit (each) output: User configurable clock outputs
			CLKOUT0 => clk_200, -- 1-bit output: CLKOUT0
			-- CLKOUT0B => CLKOUT0B, -- 1-bit output: Inverted CLKOUT0
			CLKOUT2 => i2s_mclk_int, -- 1-bit output: CLKOUT1
			-- CLKOUT1B => CLKOUT1B, -- 1-bit output: Inverted CLKOUT1
			-- CLKOUT2 => CLKOUT2, -- 1-bit output: CLKOUT2
			-- CLKOUT2B => CLKOUT2B, -- 1-bit output: Inverted CLKOUT2
			CLKOUT3 => clk_unbuffd, -- 1-bit output: CLKOUT3
			-- CLKOUT3B => CLKOUT3B, -- 1-bit output: Inverted CLKOUT3
			-- CLKOUT4 => CLKOUT4, -- 1-bit output: CLKOUT4
			-- CLKOUT5 => CLKOUT5, -- 1-bit output: CLKOUT5
			-- CLKOUT6 => CLKOUT6, -- 1-bit output: CLKOUT6
			-- Feedback Clocks: 1-bit (each) output: Clock feedback ports
			CLKFBOUT => fbclk, -- 1-bit output: Feedback clock
			CLKFBOUTB => Open, -- 1-bit output: Inverted CLKFBOUT
			-- Status Ports: 1-bit (each) output: MMCM status ports
			LOCKED => plllock, -- 1-bit output: LOCK
			-- Clock Inputs: 1-bit (each) input: Clock input
			CLKIN1 => sysclk_bufg, -- 1-bit input: Clock

			-- Control Ports: 1-bit (each) input: MMCM control ports
			PWRDWN => '0', -- 1-bit input: Power-down
			RST => RSTIN, -- 1-bit input: Reset
			-- Feedback Clocks: 1-bit (each) input: Clock feedback ports
			CLKFBIN => fbclk -- 1-bit input: Feedback clock
		);
	End Generate;

	led0_b <= led_counter(led_counter'high);
	led0_g <= led_counter(led_counter'HIGH - 6);
	led0_r <= led_counter(led_counter'HIGH - 2);

    fm_voicei : Entity work.fm_voice
	Generic Map(
		USE_MLMM            => USE_MLMM           ,
		NOTECOUNT           => NOTECOUNT          ,
		NOTECOUNTLOG2       => NOTECOUNTLOG2      ,
		PROCESS_BW          => PROCESS_BW         ,
		VOLUMEPRECISION     => VOLUMEPRECISION    ,
		PHASE_PRECISION     => PHASE_PRECISION    ,
		OPERATOR_COUNT      => OPERATOR_COUNT     ,
		OPERATOR_COUNT_LOG2 => OPERATOR_COUNT_LOG2
	)
	Port Map (
		clk                 => clk                 ,
		rst                 => rst                 ,
		
		wren_array          => wren_array          ,
		
		mm_voiceaddr        => mm_voiceaddr        ,
		mm_wrdata           => mm_wrdata           ,
		mm_voiceno0         => mm_voiceno0         ,
		mm_voiceno1         => mm_voiceno1         ,
		mm_voiceno2         => mm_voiceno2         ,
		mm_wrdata_processbw => mm_wrdata_processbw ,
		mm_wrdata_algorithm => mm_wrdata_algorithm ,
		
		env_clkdiv          => env_clkdiv,
		Z13_env_finished    => Z13_env_finished,
		
		mm_opno_onehot      => mm_opno_onehot      ,
		
        Z13_voiceamp_ready   => voice_amp_ready(0),
		Z13_voiceamp_data    => voice_amp_data   ,
		Z13_voiceamp_valid   => voice_amp_valid  ,
		Z13_VoiceIndex       => voice_amp_index       

	);
	
    voice_amp_data_slv <= Std_logic_vector(voice_amp_data);
    
	channelgain :
	For channel In 0 To CHANNEL_COUNT - 1 Generate
		channelgain_wr(channel) <= wren_array(cmd_channelgain) And mm_opno_onehot(channel);
        
		-- master env
		mm_channelgain : Entity work.mm_volume_stream
			Generic Map(
				DOUT_DATA_LEN => I2s_BITDEPTH
			)
			Port Map(
                rst                  => rst                  ,
                clk                  => clk                  ,
                
                gain_wr              => wren_array(cmd_channelgain) ,
                mm_voiceno           => mm_voiceno1          ,
                mm_wrdata_processbw  => mm_wrdata_processbw  ,
                
                Z00_VoiceIndex       => voice_amp_index        ,
                Z00_ready            => voice_amp_ready(channel)  ,
                Z00_valid            => voice_amp_valid  ,
                Z00_din_data         => voice_amp_data   ,
                
                Z03_dout_ready       => channelpostgain_ready(channel)       ,
                Z03_dout_valid       => channelpostgain_valid(channel)       ,
                Z03_dout_data        => channelpostgain_data(channel)        
			);
			
        sumtime_i : Entity work.sumtime
            Generic Map(
                ratio => NOTECOUNT
            )
            Port Map(
                clk => clk,
                rst => rst,
    
                din_ready => channelpostgain_ready(channel), -- assume identical behavior
                din_valid => channelpostgain_valid(channel),
                din_data  => channelpostgain_data(channel),
    
                dout_ready => S00_channel_ready,
                dout_valid => S00_channel_valid(channel),
                dout_data  => S00_channel_data(channel)
            ); 
            S00_channel_data_signed(channel) <= signed(std_logic_vector(S00_channel_data(channel)));
            channelproc :
            Process (clk)
            Begin
                If rising_edge(clk) Then
                    If rst = '0' Then
                        if srun(Z00) = '1' then
                        	S01_channel_shifted_signed(channel) <= shift_right(S00_channel_data_signed(channel), shiftamount);
                        end if;
                        if srun(Z01) = '1' then
		                    S02_channel_data((channel+1) *I2S_BITDEPTH -1 downto channel*I2S_BITDEPTH) <= std_logic_vector(S01_channel_shifted_signed(channel)(i2s_bitdepth - 1 Downto 0));
                        end if;
                    End If;
                End If;
            End Process;
	End Generate;

	-- output fifo
	streamToI2s : Entity work.fifo_stream_36_dual
		Port Map(
			inclk => clk,
			outclk => i2s_mclk_int,
			rst => rst,
			din_ready  => S02_channel_READY,
			din_valid  => S02_channel_VALID,
			din_data   => S02_channel_DATA,
			dout_ready => I2SOUTFIFO_READY,
			dout_valid => I2SOUTFIFO_VALID,
			dout_data  => I2SOUTFIFO_DATA
		);
		
	streamirqueue : Entity work.fifo_stream
		Port Map( 
			clk => clk,
			rst => rst,
			din_ready  => irqueue_in_READY,
			din_valid  => irqueue_in_VALID,
			din_data   => irqueue_in_DATA ,
			dout_ready => irqueue_out_READY,
			dout_valid => irqueue_out_valid_int,
			dout_data  => irqueue_out_DATA 
		);
		
    
    irqueue_out_ready   <= spi_tx_ready when TX_STREAM_SELECT = cmd_readirqueue else '0';
    audio_out_ready     <= spi_tx_ready when TX_STREAM_SELECT = cmd_readaudio   else '0';
    
    spi_tx_data <= 
    "101011110000000" & irqueue_out_data when TX_STREAM_SELECT = cmd_readirqueue else 
    X"AAAAAAAA"    when TX_STREAM_SELECT = cmd_readaudio else
    X"DEADBEEF"    ;  -- for now
    
	spi_tx_gate : Entity work.stream_gate
		Port Map( 
		clk           => clk           ,
		rst           => rst           ,
		
        amount_ready  => tx_amount_ready  ,
        amount_valid  => tx_amount_valid  ,
        amount_data   => tx_amount_data   ,
        
		din_ready     => spi_tx_ready     ,
		din_valid     => spi_tx_valid     ,
		din_data      => spi_tx_data      ,
		
		dout_ready    => spi_tx_gated_ready,
		dout_valid    => spi_tx_gated_valid,
		dout_data     => spi_tx_gated_data 
		);

	-- debug signals
	i2sproc :
	Process (i2s_mclk_int)
	Begin
		If rising_edge(i2s_mclk_int) Then
			If rst = '0' Then
				I2SOUTFIFO_FAULT <= '0';
				If I2SOUTFIFO_VALID = '1' And I2SOUTFIFO_READY = '1' Then
					I2SOUTFIFO_DATA_LAST <= unsigned(I2SOUTFIFO_DATA);
					If I2SOUTFIFO_DATA_LAST + 1 /= unsigned(I2SOUTFIFO_DATA) Then
						I2SOUTFIFO_FAULT <= '1';
					End If;
				End If;
			End If;
		End If;
	End Process;

	-- output
	i2s : Entity work.i2s_master_clocked
		Generic Map(
			BIT_DEPTH => I2S_BITDEPTH,
			CHANNEL_COUNT => CHANNEL_COUNT,
			INPUT_FREQ => 98570e3,
			SAMPLE_RATE => 96e3
		)
		Port Map(
			i2s_mclk => i2s_mclk_int,
			rst => rst,

			TX_VALID  => I2SOUTFIFO_VALID,
			TX_READY  => I2SOUTFIFO_READY,
			TX_DATA   => I2SOUTFIFO_DATA,

			RX_VALID  => I2S_RX_VALID,
			RX_READY  => I2S_RX_READY,
			RX_DATA   => I2S_RX_DATA,

			i2s_bclk  => i2s_bclk,
			i2s_lrclk => i2s_lrclk_i,
			i2s_dacsd => i2s_dacsd_i,
			i2s_adcsd => i2s_adcsd,
			i2s_begin => i2s_begin
		);

	--ss :Entity work.SPI_SLAVE_sclkdomain
	ss : Entity work.SPI_SLAVE_DUALCLOCK
		Port Map(
			clk => clk,
			rst => rst,

			SCLK => sclk,
			sclk_hold => sclk_hold,
			CS_N => SPI_CS_N,
			MOSI => SPI_MOSI,
			MISO => SPI_MISO,

			TX_DATA  => spi_tx_gated_data,
			TX_VALID => spi_tx_gated_valid,
			TX_READY => spi_tx_gated_ready,
			TX_ENABLE => spi_tx_enable,
			
			RX_DATA => SPI_RX_DATA,
			RX_VALID => SPI_RX_VALID,
			RX_READY => SPI_RX_READY
		);

	sflow_i : Entity work.flow
		Port Map(
			clk => clk,
			rst => rst,

			in_ready => S00_channel_ready,
			in_valid => S00_channel_valid(0),
			out_ready => S02_channel_ready,
			out_valid => S02_channel_valid,

			run => srun
		);
		
	ctrlproc :
	Process (clk)
	   variable or_op : unsigned(OPERATOR_COUNT_LOG2-1 downto 0);
	Begin
		If rising_edge(clk) Then
            if unsigned(soft_rst_hist) = 0  then 
                soft_rst <= '0';  
            else 
                soft_rst <= '1'; 
            end if;

            irqueue_in_valid <= '0';
            if unsigned(Z13_env_finished) /= 0 then
                irqueue_in_data  <= Z13_env_finished & voice_amp_index;
                irqueue_in_valid <= '1';
            end if;

			-- timed to switch to sclk **after** rams initialized
			rst_delay <= rst_delay(rst_delay'HIGH - 1 Downto 0) & rst;
			If signed(rst_delay) =- 1 Then
				sclk_sel <= '1';
			End If;
			If signed(rst_delay) = 0 Then
				sclk_sel <= '0';
			End If;

			If rst = '0' Then

				-- debug signals
				S02_channel_FAULT <= '0';
				If S02_channel_VALID = '1' And S02_channel_READY = '1' Then
					S02_channel_DATA_LAST <= unsigned(S02_channel_DATA);
					If S02_channel_DATA_LAST /= unsigned(S02_channel_DATA) - 1 Then
						S02_channel_FAULT <= '1';
					End If;
				End If;

				-- Global effects
				If wren_array(cmd_passthrough) = '1' Then
					passthrough <= mm_wrdata(0);
				End If;
				If wren_array(cmd_flushspi) = '1' Then
					FLUSHSPI <= mm_wrdata(0);
				End If;
				If wren_array(cmd_shift) = '1' Then
					shiftamount <= to_integer(unsigned(mm_wrdata));
				End If;
				If wren_array(cmd_env_clkdiv) = '1' Then
					env_clkdiv <= to_integer(unsigned(mm_wrdata));
				End If;
			End If;
		End If;
	End Process;
	
	SPI_RX_READY <= Not rst;
    strm2mm :
	Process (clk)
	Begin
		-- 32 Bytes address (top 8 is paramno, bottom 24 is index therein)
		If rising_edge(clk) Then
		  
			spi2mm_state_last <= spi2mm_state;
			led_counter <= led_counter + 1;

			-- usually no writes
			wren_array <= (Others => '0');
            tx_amount_valid   <= '0';
    
			If rst = '0' And SPI_CS_N = '0' Then

				If SPI_RX_VALID = '1' And SPI_RX_READY <= '1' Then
				    spi2mm_state_lastrcv <= spi2mm_state;
					Case spi2mm_state Is
						When ADDR =>

							mm_voiceaddr <= (Others => '0');
							mm_paramnum <= to_integer(unsigned(SPI_RX_DATA(31 Downto 24)));
							mm_opno_onehot <= SPI_RX_DATA(23 Downto 16);
							mm_voiceinc_mode <= SPI_RX_DATA(15);
							mm_voiceaddr <= SPI_RX_DATA;
							mm_voiceno0 <= SPI_RX_DATA(NOTECOUNTLOG2 - 1 Downto 0);
							mm_voiceno1 <= SPI_RX_DATA(NOTECOUNTLOG2 - 1 Downto 0);
							mm_voiceno2 <= SPI_RX_DATA(NOTECOUNTLOG2 - 1 Downto 0);
							spi2mm_state <= DATA;
							tx_amount_data <= to_integer(unsigned(SPI_RX_DATA(23 Downto 16)));

                            SPI_TX_ENABLE <= '0';
                            tx_stream_select <= to_integer(unsigned(SPI_RX_DATA(31 Downto 24)));
						    -- read irqueue for the next time if indicated
                            if to_integer(unsigned(SPI_RX_DATA(31 Downto 24))) = cmd_readirqueue then 
                                SPI_TX_ENABLE     <= '1';
                                tx_amount_valid   <= '1';
                            elsif to_integer(unsigned(SPI_RX_DATA(31 Downto 24))) = cmd_readaudio then 
                                SPI_TX_ENABLE     <= '1';
                                tx_amount_valid   <= '1';
                            elsif to_integer(unsigned(SPI_RX_DATA(31 Downto 24))) = cmd_readid then 
                                SPI_TX_ENABLE     <= '1';
                                tx_amount_valid   <= '1';

                            elsif to_integer(unsigned(SPI_RX_DATA(31 Downto 24))) = cmd_softreset then 
                                soft_rst_hist <= '1' & soft_rst_hist(soft_rst_hist'high downto 1);

                            end if;
            
                            
						When DATA =>
                            
							-- circular shift
							If (mm_voiceinc_mode = '0' 
							 Or (signed(mm_voiceno0) = -1)) 
							 and spi2mm_state_lastrcv = DATA Then
								mm_opno_onehot <= mm_opno_onehot(OPERATOR_COUNT - 2 Downto 0) & mm_opno_onehot(OPERATOR_COUNT - 1);
							End If;
							mm_wrdata           <= SPI_RX_DATA;
                            mm_wrdata_processbw <= SPI_RX_DATA(PROCESS_BW - 1 Downto 0);
                            mm_wrdata_algorithm <= SPI_RX_DATA(OPERATOR_COUNT * OPERATOR_COUNT_LOG2 - 1 Downto 0);

							--mm_voiceaddr <= std_logic_vector(unsigned(mm_voiceaddr) + 1);
							-- direct the write dependant on top byte of address
							If mm_paramnum < wren_array'LENGTH Then
								wren_array(mm_paramnum) <= '1';
							End If;

							-- on last operator, increase voice
							If (mm_voiceinc_mode = '1' 
							    Or (unsigned(mm_opno_onehot(OPERATOR_COUNT - 2 Downto 0)) = 0 And mm_opno_onehot(OPERATOR_COUNT - 1) = '1')) 
							    and spi2mm_state_lastrcv = DATA  Then
								-- prepare to write the next voice
								mm_voiceaddr <= Std_logic_vector(unsigned(mm_voiceaddr) + 1);
								mm_voiceno0 <= Std_logic_vector(unsigned(mm_voiceno0(NOTECOUNTLOG2 - 1 Downto 0)) + 1);
								mm_voiceno1 <= Std_logic_vector(unsigned(mm_voiceno1(NOTECOUNTLOG2 - 1 Downto 0)) + 1);
								mm_voiceno2 <= Std_logic_vector(unsigned(mm_voiceno2(NOTECOUNTLOG2 - 1 Downto 0)) + 1);
							End If;
						When Others =>
					End Case;
				End If;
			Else
                soft_rst_hist <= '0' & soft_rst_hist(soft_rst_hist'high downto 1);
				spi2mm_state <= ADDR;
			End If;
		End If;
	End Process;

   IDELAYCTRL_inst : IDELAYCTRL
   port map (
      RDY => delay_rdy,       -- 1-bit output: Ready output
      REFCLK => Clk_200, -- 1-bit input: Reference clock input
      RST => RST        -- 1-bit input: Active high reset input
   );
   
   IDELAYE2_inst : IDELAYE2
   generic map (
      CINVCTRL_SEL => "FALSE",          -- Enable dynamic clock inversion (FALSE, TRUE)
      DELAY_SRC => "DATAIN",           -- Delay input (IDATAIN, DATAIN)
      HIGH_PERFORMANCE_MODE => "FALSE", -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
      IDELAY_TYPE => "FIXED",           -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
      IDELAY_VALUE => 5,--25,               -- Input delay tap setting (0-31) (78ps/tap @ 200MHz, 2.4ns max)
      PIPE_SEL => "FALSE",              -- Select pipelined mode, FALSE, TRUE
      REFCLK_FREQUENCY => 200.0,        -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
      SIGNAL_PATTERN => "CLOCK"         -- DATA, CLOCK input signal
   )
   port map (
      CNTVALUEOUT => open,        -- 5-bit output: Counter value output
      DATAOUT => sclk_hold_pregate,       -- 1-bit output: Delayed data output
      C => '0',                   -- 1-bit input: Clock input
      CE => '0',                  -- 1-bit input: Active high enable increment/decrement input
      CINVCTRL => '0',            -- 1-bit input: Dynamic clock inversion input
      CNTVALUEIN => "00000",      -- 5-bit input: Counter value input
      DATAIN => spi_sclk,         -- 1-bit input: Internal delay data input
      IDATAIN => '0',             -- 1-bit input: Data input from the I/O
      INC => '0',                 -- 1-bit input: Increment / Decrement tap delay input
      LD => '0',                  -- 1-bit input: Load IDELAY_VALUE input
      LDPIPEEN => '0',            -- 1-bit input: Enable PIPELINE register to load data input
      REGRST => delay_rdy         -- 1-bit input: Active-high reset tap-delay input
   );

End arch_imp;
