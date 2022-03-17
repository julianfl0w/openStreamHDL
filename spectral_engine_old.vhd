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
Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

Entity spectral_engine Is
	Generic (
		USE_MLMM : Integer := 1;
		NOTE_COUNT : Integer := 1024;
		PROCESS_BW : Integer := 18;
		CTRL_COUNT : Integer := 4;
		CHANNEL_COUNT : Integer := 2;
		VOLUMEPRECISION : Integer := 16;
		I2S_BITDEPTH : Integer := 24;
		PHASEPRECISION : Integer := 32;
		SINESPEROCTAVE_ADDRBW : Integer := 11;
		SINES_ADDRBW : Integer := 14;
		MAX_HARMONICS : Integer := 16;
		TOTAL_SINES_ADDRBW : Integer := 14;
		BANKCOUNT : Integer := 12;
		SINESPERBANK : Integer := 1024;
		CYCLE_BW : Integer := 3;
		SINESPERBANK_ADDRBW : Integer := 10
	);
	Port (
		sysclk : In Std_logic;
		rstin : In Std_logic;

		-- SPI SLAVE INTERFACE
		SCLK : In Std_logic; -- SPI clock
		CS_N : In Std_logic; -- SPI chip select, active in low
		MOSI : In Std_logic; -- SPI serial data from master to slave
		MISO : Out Std_logic; -- SPI serial data from slave to master

		i2s_bclk : Out Std_logic;
		i2s_mclk : Out Std_logic;
		i2s_lrclk : Out Std_logic := '1';
		i2s_dacsd : Out Std_logic := '0';
		i2s_adcsd : In Std_logic;

		btn : In Std_logic_vector(1 Downto 0) := (Others => '0');
		led : Out Std_logic_vector(1 Downto 0) := (Others => '0');
		led0_b : Out Std_logic := '1';
		led0_g : Out Std_logic := '1';
		led0_r : Out Std_logic := '1';
		
		halt : Out Std_logic := '1'
	);

End spectral_engine;

Architecture arch_imp Of spectral_engine Is

    signal i2s_lrclk_i : Std_logic := '1';
    signal i2s_dacsd_i : Std_logic := '0';
    
    attribute mark_debug : string;
    attribute mark_debug of i2s_lrclk_i: signal is "true";
    attribute mark_debug of i2s_dacsd_i: signal is "true";
    
	Signal fbclk : Std_logic := '1';
	Signal plllock : Std_logic := '1';
	Signal clk_unbuffd : Std_logic := '1';
	Signal clk : Std_logic := '1';
	Signal rst : Std_logic := '1';

    constant COUNTER_WIDTH : integer := 32;
	Signal counter : unsigned(COUNTER_WIDTH-1 Downto 0) := (Others => '0');
	Signal ram_rst : Std_logic := '0';
	Signal initializeRam_out0 : Std_logic := '1';
	Signal initializeRam_out1 : Std_logic := '1';

	Type spi2mm_statetype Is (IDLE, ADDR1, ADDR2, ADDR3, LENGTH0, DATA0, DATA1, DATA2, DATA3);
	Signal spi2mm_state : spi2mm_statetype;
	Signal spi2mm_state_last : spi2mm_statetype;
	signal statechange : std_logic;
    attribute mark_debug of statechange        : signal is "true";
    attribute mark_debug of spi2mm_state       : signal is "true";
    attribute mark_debug of spi2mm_state_last  : signal is "true";

	Signal SPI_TX_DATA : Std_logic_vector(7 Downto 0); -- input data for SPI master
	Signal SPI_TX_VALID : Std_logic; -- when DIN_VALID = 1, input data are valid
	Signal SPI_TX_READY : Std_logic; -- when DIN_READY = 1, valid input data are accept

   	Signal SPI_RX_DATA : Std_logic_vector(7 Downto 0); -- output data from SPI master
	Signal SPI_RX_VALID : Std_logic; -- when DOUT_VALID = 1, output data are valid
	Signal SPI_RX_READY : Std_logic;

    attribute mark_debug of SPI_RX_DATA  : signal is "true";
    attribute mark_debug of SPI_RX_VALID : signal is "true";
    attribute mark_debug of SPI_RX_READY : signal is "true";
    
	Signal PCM_TVALID : Std_logic := '0';
	Signal PCM_TREADY : Std_logic := '1';
	Signal PCM_TDATA : Std_logic_vector(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');
	
    attribute mark_debug of PCM_TVALID : signal is "true";
    attribute mark_debug of PCM_TREADY : signal is "true";
    --attribute mark_debug of PCM_TDATA  : signal is "true";

	Signal I2S_RX_VALID : Std_logic;
	Signal I2S_RX_READY : Std_logic := '1';
	Signal I2S_RX_DATA : Std_logic_vector(I2s_BITDEPTH * CHANNEL_COUNT - 1 Downto 0) := (Others => '0');

	Signal i2s_begin : Std_logic;
	Signal mm_wraddr : Std_logic_vector(31 Downto 0) := (Others => '0');
	Signal note_wraddr : Std_logic_vector(31 Downto 0) := (Others => '0');
	Signal mm_notenum : unsigned(7 Downto 0) := (Others => '0');
	Signal mm_paramnum : Integer := 0;
	Signal mm_additional0 : Integer := 0;
	Signal mm_additional1 : Integer := 0;
	Signal mm_length : Integer := 0;
	Signal mm_wrdata : Std_logic_vector(31 Downto 0) := (Others => '0');
	Signal mm_wrdata_processbw : Std_logic_vector(PROCESS_BW-1 Downto 0) := (Others => '0');
    attribute mark_debug of mm_wrdata: signal is "true";

	Signal AMPARRAY_WREN     : Std_logic_vector(BANKCOUNT - 1 Downto 0);
	Signal AMPARRAY_WRADDR   : Std_logic_vector(SINESPERBANK_ADDRBW - 1 Downto 0);
	Signal amparray_wrdata   : Std_logic_vector(VOLUMEPRECISION - 1 Downto 0) := (Others => '0');
	Signal amparray_CURRCYCLE : Std_logic_vector(CYCLE_BW - 1 Downto 0);

    attribute mark_debug of AMPARRAY_WREN      : signal is "true";
    attribute mark_debug of AMPARRAY_WRADDR    : signal is "true";
    attribute mark_debug of amparray_wrdata    : signal is "true";
    attribute mark_debug of amparray_CURRCYCLE : signal is "true";

    
	Signal hwidth_wr      : Std_logic := '0';
	Signal hwidth_inv_wr  : Std_logic := '0';
	Signal basenote_wr    : Std_logic := '0';
	Signal harmonic_en_wr : Std_logic := '0';
	Signal fmfactor_wr    : Std_logic := '0';
	Signal fmdepth_wr     : Std_logic := '0';
	Signal centsinc_wr    : Std_logic := '0';
	Signal gain_wr   : Std_logic := '0';
    attribute mark_debug of hwidth_wr     : signal is "true";
    attribute mark_debug of hwidth_inv_wr : signal is "true";
    attribute mark_debug of basenote_wr   : signal is "true";
    attribute mark_debug of harmonic_en_wr: signal is "true";
    attribute mark_debug of fmfactor_wr   : signal is "true";
    attribute mark_debug of fmdepth_wr    : signal is "true";
    attribute mark_debug of centsinc_wr   : signal is "true";
    attribute mark_debug of gain_wr   : signal is "true";
	Signal envelope_env_bezier_MIDnENDpoint_wr : Std_logic := '0';
	Signal envelope_env_speed_wr               : Std_logic := '0';
	Signal pbend_env_bezier_MIDnENDpoint_wr    : Std_logic := '0';
	Signal pbend_env_speed_wr                  : Std_logic := '0';
	Signal hwidth_env_3EndPoints_wr            : Std_logic := '0';
	Signal hwidth_env_speed_wr                 : Std_logic := '0';
	Signal nfilter_env_bezier_3EndPoints_wr    : Std_logic := '0';
	Signal nfilter_env_speed_wr                : Std_logic := '0';
	Signal gfilter_env_bezier_3EndPoints_wr    : Std_logic := '0';
	Signal gfilter_env_speed_wr                : Std_logic := '0';

    attribute mark_debug of envelope_env_bezier_MIDnENDpoint_wr : signal is "true";
    attribute mark_debug of envelope_env_speed_wr               : signal is "true";
    attribute mark_debug of pbend_env_bezier_MIDnENDpoint_wr    : signal is "true";
    attribute mark_debug of pbend_env_speed_wr                  : signal is "true";
    attribute mark_debug of hwidth_env_3EndPoints_wr            : signal is "true";
    attribute mark_debug of hwidth_env_speed_wr                 : signal is "true";
    attribute mark_debug of nfilter_env_bezier_3EndPoints_wr    : signal is "true";
    attribute mark_debug of nfilter_env_speed_wr                : signal is "true";
    attribute mark_debug of gfilter_env_bezier_3EndPoints_wr    : signal is "true";
    attribute mark_debug of gfilter_env_speed_wr                : signal is "true";
    
	Signal run : Std_logic_vector(Z21 Downto Z00) := (Others => '0');

	Signal IRQueue_out_ready : Std_logic := '0';
	Signal IRQueue_out_valid : Std_logic := '0';
	Signal IRQueue_out_data : Std_logic_vector(15 Downto 0) := (Others => '0');
	Signal OUTBYTE : Integer := 0;
Begin
    mm_wrdata_processbw <= mm_wrdata(PROCESS_BW-1 downto 0);
	statechange <= '1' when spi2mm_state /= spi2mm_state_last else '0';
    i2s_lrclk <= i2s_lrclk_i ;
    i2s_dacsd <= i2s_dacsd_i ;

	rst <= rstin Or Not plllock Or ram_rst;
    halt<= rst;
	passthrugen :
	If USE_MLMM = 0 Generate
		clk <= sysclk;
	End Generate;

	mlmmgen :
	If USE_MLMM = 1 Generate
	   
       BUFG_inst : BUFG
       port map (
          O => clk, -- 1-bit output: Clock output
          I => clk_unbuffd  -- 1-bit input: Clock input
       );
       
		MMCME2_BASE_inst : MMCME2_BASE
		Generic Map(
			BANDWIDTH => "OPTIMIZED", -- Jitter programming (OPTIMIZED, HIGH, LOW)
			CLKFBOUT_MULT_F => 57.5, -- Multiply value for all CLKOUT (2.000-64.000).
			CLKFBOUT_PHASE => 0.0, -- Phase offset in degrees of CLKFB (-360.000-360.000).
			CLKIN1_PERIOD => 83.3333333, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
			-- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
			CLKOUT1_DIVIDE => 7,
			CLKOUT2_DIVIDE => 1,
			CLKOUT3_DIVIDE => 1,
			CLKOUT4_DIVIDE => 1,
			CLKOUT5_DIVIDE => 1,
			CLKOUT6_DIVIDE => 1,
			CLKOUT0_DIVIDE_F => 1.0, -- Divide amount for CLKOUT0 (1.000-128.000).
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
			CLKOUT1 => clk_unbuffd, -- 1-bit output: CLKOUT0
			-- CLKOUT0B => CLKOUT0B,   -- 1-bit output: Inverted CLKOUT0
			-- CLKOUT1 => CLKOUT1,     -- 1-bit output: CLKOUT1
			-- CLKOUT1B => CLKOUT1B,   -- 1-bit output: Inverted CLKOUT1
			-- CLKOUT2 => CLKOUT2,     -- 1-bit output: CLKOUT2
			-- CLKOUT2B => CLKOUT2B,   -- 1-bit output: Inverted CLKOUT2
			-- CLKOUT3 => CLKOUT3,     -- 1-bit output: CLKOUT3
			-- CLKOUT3B => CLKOUT3B,   -- 1-bit output: Inverted CLKOUT3
			-- CLKOUT4 => CLKOUT4,     -- 1-bit output: CLKOUT4
			-- CLKOUT5 => CLKOUT5,     -- 1-bit output: CLKOUT5
			-- CLKOUT6 => CLKOUT6,     -- 1-bit output: CLKOUT6
			-- Feedback Clocks: 1-bit (each) output: Clock feedback ports
			CLKFBOUT => fbclk, -- 1-bit output: Feedback clock
			CLKFBOUTB => Open, -- 1-bit output: Inverted CLKFBOUT
			-- Status Ports: 1-bit (each) output: MMCM status ports
			LOCKED => plllock, -- 1-bit output: LOCK
			-- Clock Inputs: 1-bit (each) input: Clock input
			CLKIN1 => sysclk, -- 1-bit input: Clock
			-- Control Ports: 1-bit (each) input: MMCM control ports
			PWRDWN => '0', -- 1-bit input: Power-down
			RST => RSTIN, -- 1-bit input: Reset
			-- Feedback Clocks: 1-bit (each) input: Clock feedback ports
			CLKFBIN => fbclk -- 1-bit input: Feedback clock
		);
	End Generate;

	led0_b <= counter(counter'high);
	led0_g <= counter(counter'high - 6);
	led0_r <= counter(counter'high - 2);

	rar : Entity work.ram_active_rst
		Port Map(
			slowclk => clk,
			rstin => rstin,
			clksRdy => plllock,
			ram_rst => ram_rst,
			initializeRam_out0 => initializeRam_out0,
			initializeRam_out1 => initializeRam_out1
		);
	sb : Entity work.sine_bank
		Generic Map(

			PHASEPRECISION => 32,
			VOLUMEPRECISION => 16,
			I2S_BITDEPTH => I2S_BITDEPTH,
			CHANNEL_COUNT => 2
		)
		Port Map(
			clk => clk,
			rst => rst,

			Z00_volume_wren => amparray_wren,
			Z00_volume_wrdata => amparray_wrdata,
			Z00_volume_wraddr => amparray_wraddr,
			Z00_volume_currcycle => amparray_currcycle,

			S16_PCM_TVALID => PCM_TVALID,
			S16_PCM_TREADY => PCM_TREADY,
			S16_PCM_TDATA => PCM_TDATA
		);

	i2s : Entity work.i2s_master
		Generic Map(
			BIT_DEPTH => I2S_BITDEPTH,
			CHANNEL_COUNT => CHANNEL_COUNT,
			INPUT_FREQ => 98570e3,
			SAMPLE_RATE => 96e3
		)
		Port Map(
			clk => clk,
			rst => rst,

			TX_VALID => PCM_TVALID,
			TX_READY => PCM_TREADY,
			TX_DATA => PCM_TDATA,

			RX_VALID => I2S_RX_VALID,
			RX_READY => I2S_RX_READY,
			RX_DATA => I2S_RX_DATA,

			i2s_bclk  => i2s_bclk,
			i2s_lrclk => i2s_lrclk_i,
			i2s_dacsd => i2s_dacsd_i,
			i2s_adcsd => i2s_adcsd,
			i2s_mclk  => i2s_mclk,
			i2s_begin => i2s_begin
		);

	sn : Entity work.spectral_note
		Generic Map(
			-- Users to add parameters here

			-- User parameters ends
			-- Do not modify the parameters beyond this line

			PHASEPRECISION => 32,
			CHANNEL_COUNT => 2,
			NOTE_COUNT => 128,
			CTRL_COUNT => 4,
			MAX_HARMONICS => 31,
			PROCESS_BW => 18
		)
		Port Map(
			clk => clk,
			rst => rst,

			Z22_AMPARRAY_WREN => AMPARRAY_WREN,
			Z22_AMPARRAY_WRADDR => AMPARRAY_WRADDR,
			Z22_amparray_wrdata => amparray_wrdata,
			Z22_amparray_CURRCYCLE => amparray_CURRCYCLE,

			hwidth_inv_wr => hwidth_inv_wr,
			hwidth_wr => hwidth_wr,
			basenote_wr => basenote_wr,
			harmonic_en_wr => harmonic_en_wr,
			fmfactor_wr => fmfactor_wr,
			fmdepth_wr => fmdepth_wr,
			centsinc_wr => centsinc_wr,

			envelope_env_bezier_MIDnENDpoint_wr => envelope_env_bezier_MIDnENDpoint_wr,
			envelope_env_speed_wr => envelope_env_speed_wr,

			pbend_env_speed_wr => pbend_env_speed_wr,
			pbend_env_bezier_MIDnENDpoint_wr => pbend_env_bezier_MIDnENDpoint_wr,

			hwidth_env_3EndPoints_wr => hwidth_env_3EndPoints_wr,
			hwidth_env_speed_wr => hwidth_env_speed_wr,

			nfilter_env_bezier_3EndPoints_wr => nfilter_env_bezier_3EndPoints_wr,
			nfilter_env_speed_wr => nfilter_env_speed_wr,

			gfilter_env_bezier_3EndPoints_wr => gfilter_env_bezier_3EndPoints_wr,
			gfilter_env_speed_wr => gfilter_env_speed_wr,

			IRQueue_out_ready => IRQueue_out_ready,
			IRQueue_out_valid => IRQueue_out_valid,
			IRQueue_out_data => IRQueue_out_data,

			mm_wraddr => mm_wraddr,
			mm_wrdata => mm_wrdata
		);

	ss : Entity work.SPI_SLAVE
		Port Map(
			CLK => CLK,
			RST => RST,

			SCLK => SCLK,
			CS_N => CS_N,
			MOSI => MOSI,
			MISO => MISO,

			TX_DATA  => SPI_TX_DATA,
			TX_VALID => SPI_TX_VALID,
			TX_READY => SPI_TX_READY,

			RX_DATA  => SPI_RX_DATA,
			RX_VALID => SPI_RX_VALID,
			RX_READY => SPI_RX_READY
		);
	-- ready to read must be concurrent
	IRQueue_out_ready <= '1' When spi2mm_state = DATA3 And mm_paramnum = 0 And OUTBYTE = 0 Else '0';

	-- only thing were sending right now is irqs when requested
	SPI_TX_VALID <= IRQueue_out_valid And IRQueue_out_ready;
	-- big endian data send
	SPI_TX_DATA <= IRQueue_out_data(15 Downto 8) When OUTBYTE = 0 Else
		IRQueue_out_data(7 Downto 0) When OUTBYTE = 1;

	strm2mm :
	Process (clk)
	Begin
		-- 32 Bytes address (top 8 is paramno, bottom 24 is index therein)
		If rising_edge(clk) Then
		    spi2mm_state_last <= spi2mm_state;
		
			counter <= counter + 1;
			-- usually no writes 
			envelope_env_bezier_MIDnENDpoint_wr <= '0';
			envelope_env_speed_wr <= '0';

			pbend_env_bezier_MIDnENDpoint_wr <= '0';
			pbend_env_speed_wr <= '0';

			hwidth_env_3EndPoints_wr <= '0';
			hwidth_env_speed_wr <= '0';

			nfilter_env_bezier_3EndPoints_wr <= '0';
			nfilter_env_speed_wr <= '0';

			gfilter_env_bezier_3EndPoints_wr <= '0';
			gfilter_env_speed_wr <= '0';

			hwidth_wr      <= '0';
			hwidth_inv_wr  <= '0';
			basenote_wr    <= '0';
			harmonic_en_wr <= '0';
			fmfactor_wr    <= '0';
			fmdepth_wr     <= '0';
			centsinc_wr    <= '0';
			gain_wr        <= '0';

			SPI_RX_READY <= '1';
			If rst = '0' And CS_N = '0' Then

				If SPI_RX_VALID = '1' Then
					SPI_RX_READY <= '0';
					mm_length <= mm_length - 1;
					Case spi2mm_state Is
						When IDLE =>

							mm_wraddr <= (Others => '0');
							note_wraddr <= (Others => '0');
							mm_notenum <= (Others => '0');
							mm_paramnum <= 0;
							mm_additional0 <= 0;
							mm_additional1 <= 0;
							mm_length <= 0;
							mm_wrdata <= (Others => '0');

							OUTBYTE <= 0;
							mm_wraddr(31 Downto 24) <= SPI_RX_DATA;
							mm_notenum <= unsigned(SPI_RX_DATA);
							spi2mm_state <= ADDR1;
						When ADDR1 =>
							mm_wraddr(23 Downto 16) <= SPI_RX_DATA;
							mm_paramnum <= to_integer(unsigned(SPI_RX_DATA));
							spi2mm_state <= ADDR2;
						When ADDR2 =>
							mm_wraddr(15 Downto 8) <= SPI_RX_DATA;
							mm_additional0 <= to_integer(unsigned(SPI_RX_DATA));
							spi2mm_state <= ADDR3;
						When ADDR3 =>
							mm_wraddr(7 Downto 0) <= SPI_RX_DATA;
							mm_additional1 <= to_integer(unsigned(SPI_RX_DATA));
							spi2mm_state <= DATA0;
						When DATA0 =>
							mm_wrdata(31 Downto 24) <= SPI_RX_DATA;
							spi2mm_state <= DATA1;
						When DATA1 =>
							mm_wrdata(23 Downto 16) <= SPI_RX_DATA;
							spi2mm_state <= DATA2;
						When DATA2 =>
							mm_wrdata(15 Downto 8) <= SPI_RX_DATA;
							spi2mm_state <= DATA3;
						When DATA3 =>
							mm_wrdata(7 Downto 0) <= SPI_RX_DATA;
							--mm_wraddr <= std_logic_vector(unsigned(mm_wraddr) + 1);
							-- direct the write dependant on top byte of address

							Case(mm_paramnum) Is
							When 0 =>
								-- read one reset irq
								OUTBYTE <= OUTBYTE + 1;
							When ENVELOPE_MIDnEND =>
								envelope_env_bezier_MIDnENDpoint_wr <= '1';
							When envelope_ENV_SPEED =>
								envelope_env_speed_wr <= '1';

							When PBEND_MIDnEND =>
								pbend_env_bezier_MIDnENDpoint_wr <= '1';
							When PBEND_ENV_SPEED =>
								pbend_env_speed_wr <= '1';

							When HWIDTH_3TARGETS =>
								hwidth_env_3EndPoints_wr <= '1';
							When HWIDTH_ENV_SPEED =>
								hwidth_env_speed_wr <= '1';

							When NFILTER_3TARGETS =>
								nfilter_env_bezier_3EndPoints_wr <= '1';
							When NFILTER_ENV_SPEED =>
								nfilter_env_speed_wr <= '1';

							When GFILTER_3TARGETS =>
								gfilter_env_bezier_3EndPoints_wr <= '1';
							When GFILTER_ENV_SPEED =>
								gfilter_env_speed_wr <= '1';

							When HARMONIC_WIDTH =>
								hwidth_wr <= '1';
							When HARMONIC_BASENOTE =>
								basenote_wr <= '1';
							When HARMONIC_ENABLE =>
								harmonic_en_wr <= '1';
							When HARMONIC_WIDTH_INV =>
								hwidth_inv_wr <= '1';
							When fmfactor =>
								fmfactor_wr <= '1';
							When fmdepth =>
								fmdepth_wr <= '1';
							When centsinc =>
								centsinc_wr <= '1';
							When gain =>
								gain_wr <= '1';
							When Others =>
							End Case;

							spi2mm_state <= IDLE;
						When Others =>
					End Case;
				End If;
			Else
				spi2mm_state <= IDLE;
			End If;
		End If;
	End Process;

End arch_imp;