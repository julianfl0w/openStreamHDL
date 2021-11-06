----------------------------------------------------------------------------------
-- Engineer: Julian Loiacono 6/2016
----------------------------------------------------------------------------------

-- here's what this nutso thing does
-- first, look at the flow diagram in Julius O Smith's paramstate Variable Filter writeup
-- we need to run a single pole twice, effectively doubling the input sample rate
-- thats what the OVERSAMPLEFACTOR is
-- the rest is just implimentation
-- and plumbing
-- hopefully this code never breaks lol
-- if each SVF oversample is 7 clocks (prime WRT 1024 so processes dont overlap)
-- and a new independant sample arrives every 4 clocks
-- total length of a process is 7*4 = 28 clocks

Library IEEE;
Use IEEE.STD_LOGIC_1164.All;
Use IEEE.NUMERIC_STD.All;
Library work;
Use work.memory_word_type.All;
Use work.fixed_pkg.All;

Entity note_svf Is

	Port (
		clk100 : In Std_logic;
		ZN5_ADDR : In unsigned (RAMADDR_WIDTH - 1 Downto 0);

		Z20_FILTER_OUT : Out sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');
		Z00_FILTER_IN : In sfixed(1 Downto -STD_FLOWWIDTH + 2);

		Z05_OS : In oneshotspervoice_by_ramwidth18s;
		Z05_COMPUTED_ENVELOPE : In inputcount_by_ramwidth18s;

		MEM_WRADDR : In Std_logic_vector(RAMADDR_WIDTH - 1 Downto 0);
		MEM_IN : In Std_logic_vector(ram_width18 - 1 Downto 0);
		VOICE_FILTQ_WREN : In Std_logic;
		VOICE_FILTF_WREN : In Std_logic;
		FILT_FDRAW : In instcount_by_polecount_by_drawslog2;
		FILT_QDRAW : In instcount_by_polecount_by_drawslog2;
		FILT_FTYPE : In instcount_by_polecount_by_ftypeslog2;

		ram_rst100 : In Std_logic;
		initRam100 : In Std_logic;
		OUTSAMPLEF_ALMOSTFULL : In Std_logic
	);

End note_svf;

Architecture Behavioral Of note_svf Is

	Component ram_controller_18k_18 Is
		Port (
			DO : Out Std_logic_vector (ram_width18 - 1 Downto 0);
			DI : In Std_logic_vector (ram_width18 - 1 Downto 0);
			RDADDR : In Std_logic_vector (9 Downto 0);
			RDCLK : In Std_logic;
			RDEN : In Std_logic;
			REGCE : In Std_logic;
			RST : In Std_logic;
			WE : In Std_logic_vector (1 Downto 0);
			WRADDR : In Std_logic_vector (9 Downto 0);
			WRCLK : In Std_logic;
			WREN : In Std_logic);
	End Component;

	Component ram_controller_36k_25 Is
		Port (
			DO : Out Std_logic_vector (STD_FLOWWIDTH - 1 Downto 0);
			DI : In Std_logic_vector (STD_FLOWWIDTH - 1 Downto 0);
			RDADDR : In Std_logic_vector (9 Downto 0);
			RDCLK : In Std_logic;
			RDEN : In Std_logic;
			REGCE : In Std_logic;
			RST : In Std_logic;
			WE : In Std_logic_vector (3 Downto 0);
			WRADDR : In Std_logic_vector (9 Downto 0);
			WRCLK : In Std_logic;
			WREN : In Std_logic);
	End Component;

	Component param_lpf Is
		Port (
			clk100 : In Std_logic;

			ZN2_ADDR_IN : In unsigned (RAMADDR_WIDTH - 1 Downto 0);
			Z00_PARAM_IN : In signed(ram_width18 - 1 Downto 0);
			Z01_ALPHA_IN : In signed(ram_width18 - 1 Downto 0);
			Z00_PARAM_OUT : Out signed(ram_width18 - 1 Downto 0);

			initRam100 : In Std_logic;
			ram_rst100 : In Std_logic;
			OUTSAMPLEF_ALMOSTFULL : In Std_logic
		);
	End Component;

	Attribute mark_debug : String;

	Constant MAX_PATH_LENGTH : Integer := 7;
	Type polecount_by_stdflowwidth Is Array(0 To polecount - 1) Of sfixed(1 Downto -STD_FLOWWIDTH + 2);

	Signal SVF_ALPHA : signed (RAM_WIDTH18 - 1 Downto 0) := to_signed(2 ** 10, RAM_WIDTH18);

	-- unused ram signals
	Signal RAM_REGCE : Std_logic := '0';
	Signal RAM18_WE : Std_logic_vector(1 Downto 0) := "11";
	Signal RAM36_WE : Std_logic_vector(3 Downto 0) := "1111";
	Signal RAM18_WE_DUB : Std_logic_vector(3 Downto 0) := "1111";
	Signal RAM36_WE_DUB : Std_logic_vector(3 Downto 0) := "1111";

	Signal Z05_FILT_FDRAW : unsigned(drawslog2 - 1 Downto 0);
	Signal Z05_F : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z07_F_LPF : signed(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z06_F : signed(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z07_F : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');

	Signal Z05_Q : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z06_Q_LPF : signed(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z06_Q : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal Z05_FILT_QDRAW : unsigned(drawslog2 - 1 Downto 0);

	Signal ZN3_F_LPF : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');
	Signal ZN1_Q_LPF : Std_logic_vector(RAM_WIDTH18 - 1 Downto 0) := (Others => '0');

	Signal ZN2_BP : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal ZN1_POSTF0 : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal Z02_SUM : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal Z02_POSTQ : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal Z03_HP : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal Z04_POLE_OUT : polecount_by_stdflowwidth := (Others => (Others => '0'));
	Signal Z04_POSTF1 : polecount_by_stdflowwidth := (Others => (Others => '0'));

	Signal Z00_timeDiv : unsigned(1 Downto 0);
	Signal Z01_timeDiv : unsigned(1 Downto 0);
	Signal Z02_timeDiv : unsigned(1 Downto 0);
	Signal Z03_timeDiv : unsigned(1 Downto 0);

	Type topole_propagate_inner Is Array (Z00 To Z03) Of sfixed(1 Downto -STD_FLOWWIDTH + 2);
	Type topole_propagatetype Is Array (0 To polecount - 1) Of topole_propagate_inner;
	Signal POLE_IN : topole_propagatetype := (Others => (Others => (Others => '0')));

	Type lp_propagate_inner Is Array (ZN1 To Z07) Of sfixed(1 Downto -STD_FLOWWIDTH + 2);
	Type lp_propagatetype Is Array (0 To polecount - 1) Of lp_propagate_inner;
	Signal LP : lp_propagatetype := (Others => (Others => (Others => '0')));

	Type bp_propagate_inner Is Array (ZN2 To Z05) Of sfixed(1 Downto -STD_FLOWWIDTH + 2);
	Type bp_propagatetype Is Array (0 To polecount - 1) Of bp_propagate_inner;
	Signal BP : bp_propagatetype := (Others => (Others => (Others => '0')));

	Type f_propagate_inner Is Array (ZN2 To Z04) Of sfixed(1 Downto -RAM_WIDTH18 + 2);
	Type f_propagatetype Is Array (0 To polecount - 1) Of f_propagate_inner;
	Signal F : f_propagatetype := (Others => (Others => (Others => '0')));

	-- Q has 2 extra bits to accomodate values larger than 1
	Type q_propagate_inner Is Array (Z00 To MAX_PATH_LENGTH) Of sfixed(3 Downto -RAM_WIDTH18 + 4);
	Type q_propagatetype Is Array (0 To polecount - 1) Of q_propagate_inner;
	Signal Q : q_propagatetype := (Others => (Others => (Others => '0')));

	Signal ZN4_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal ZN3_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal ZN2_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal ZN1_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal SVF_Z00_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z01_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z02_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z03_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z04_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z05_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z06_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z07_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z22_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z27_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0');

	Signal RAM_WREN : Std_logic := '0';
	Signal RAM_RDEN : Std_logic := '0';
	Signal VOICE_FILTQandF_RDEN : Std_logic := '0';

	Signal Z04_currInst : Integer Range 0 To instcountlog2 - 1;

	Type Z02currinstarray Is Array (0 To polecount - 1) Of unsigned(RAMADDR_WIDTH - 1 Downto 0);
	Signal Z02_currInst : Z02currinstarray := (Others => (Others => '0'));
	Type Z03currtypearray Is Array (0 To polecount - 1) Of Integer Range 0 To ftypescount - 1;
	Signal Z03_currtype : Z03currtypearray := (Others => 0);

	Signal Z03_currtype_debug : unsigned(ftypeslog2 - 1 Downto 0);

	Signal ZN2_LP_OUT : Std_logic_vector(STD_FLOWWIDTH - 1 Downto 0) := (Others => '0');
	Signal ZN3_BP_OUT : Std_logic_vector(STD_FLOWWIDTH - 1 Downto 0) := (Others => '0');
	Signal Z27_BP_IN : Std_logic_vector(STD_FLOWWIDTH - 1 Downto 0) := (Others => '0');
	Signal Z22_LP_IN : Std_logic_vector(STD_FLOWWIDTH - 1 Downto 0) := (Others => '0');

Begin
	RAM_RDEN <= Not OUTSAMPLEF_ALMOSTFULL;
	Z00_timeDiv <= ZN4_ADDR(1 Downto 0);
	Z01_timeDiv <= ZN3_ADDR(1 Downto 0);
	Z02_timeDiv <= ZN2_ADDR(1 Downto 0);
	Z03_timeDiv <= ZN1_ADDR(1 Downto 0);

	RAM_RDEN <= Not OUTSAMPLEF_ALMOSTFULL;
	VOICE_FILTQandF_RDEN <= Not OUTSAMPLEF_ALMOSTFULL;

	Z04_currInst <= to_integer(Z04_ADDR(RAMADDR_WIDTH - 1 Downto RAMADDR_WIDTH - instcountlog2));

	-- timing proc does basic plumbing and timing
	-- kind of a catchall process
	timing_proc : Process (clk100)
	Begin
		If rising_edge(clk100) Then
			RAM_WREN <= '0';
			If initRam100 = '0' And OUTSAMPLEF_ALMOSTFULL = '0' Then
				RAM_WREN <= '1';
				ZN4_ADDR <= ZN5_ADDR;
				ZN3_ADDR <= ZN4_ADDR;
				ZN2_ADDR <= ZN3_ADDR;
				ZN1_ADDR <= ZN2_ADDR;
				SVF_Z00_ADDR <= ZN1_ADDR;
				Z01_ADDR <= SVF_Z00_ADDR;
				Z02_ADDR <= Z01_ADDR;
				Z03_ADDR <= Z02_ADDR;
				Z04_ADDR <= Z03_ADDR;
				Z05_ADDR <= Z04_ADDR;
				Z06_ADDR <= Z05_ADDR;
				Z07_ADDR <= Z06_ADDR;
				Z22_ADDR <= ZN1_ADDR - 22;
				Z27_ADDR <= ZN1_ADDR - 27;

				Z03_currtype_debug <= to_unsigned(FILT_FTYPE(to_integer(Z02_currinst(0)(ramaddr_width - 1 Downto ramaddr_width - instcountlog2)), 0), ftypeslog2);

				-- only read into filter out such that filter out changes every
				-- 4 clocks, 0-aligned. this keeps us from sending junk to the next element
				-- 19 % 4 = 3
				If Z03_timeDiv = 0 Then
					Z20_FILTER_OUT <= Z04_POLE_OUT(3);
				End If;

				-- LP output is good on Z00 + MAXPATH*3 = 21
				-- 21 % 4 = Z01 time div
				Z22_LP_IN <= Std_logic_vector(LP(to_integer(Z01_timeDiv))(Z00));

				-- BP output is good on Z05 + MAXPATH*3 = 26
				-- 26 % 4 = Z02 time div
				Z27_BP_IN <= Std_logic_vector(BP(to_integer(Z02_timediv))(Z05));
				Z05_FILT_FDRAW <= FILT_FDRAW(Z04_currInst, to_integer(Z00_timeDiv));
				Z06_F <= CHOOSEMOD3(Z05_FILT_FDRAW, signed(Z05_F), Z05_OS, Z05_COMPUTED_ENVELOPE);
				Z07_F <= Std_logic_vector(Z06_F);

				Z05_FILT_QDRAW <= FILT_QDRAW(Z04_currInst, to_integer(Z00_timeDiv));
				Z06_Q <= Std_logic_vector(CHOOSEMOD3(Z05_FILT_QDRAW, signed(Z05_Q), Z05_OS, Z05_COMPUTED_ENVELOPE));

			End If;
		End If;
	End Process;
	-- filtf ram
	i_filtf_ram : ram_controller_18k_18
	Port Map(
		DO => Z05_F,
		DI => MEM_IN,
		RDADDR => Std_logic_vector(Z04_ADDR),
		RDCLK => clk100,
		RDEN => VOICE_FILTQandF_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => MEM_WRADDR,
		WRCLK => clk100,
		WREN => VOICE_FILTF_WREN);

	i_f_lpf : param_lpf Port Map(
		clk100 => clk100,

		ZN2_ADDR_IN => Z05_ADDR,
		Z00_PARAM_IN => signed(Z07_F),
		Z01_ALPHA_IN => signed(SVF_ALPHA),
		Z00_PARAM_OUT => Z07_F_LPF,

		initRam100 => initRam100,
		ram_rst100 => ram_rst100,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);
	-- filtf ram lpf
	i_filtf_ram_lpf : ram_controller_18k_18
	Port Map(
		DO => ZN3_F_LPF,
		DI => Std_logic_vector(Z07_F_LPF),
		RDADDR => Std_logic_vector(ZN4_ADDR),
		RDCLK => clk100,
		RDEN => VOICE_FILTQandF_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => Std_logic_vector(Z07_ADDR),
		WRCLK => clk100,
		WREN => RAM_WREN);

	-- filtf ram
	i_filtq_ram : ram_controller_18k_18
	Port Map(
		DO => Z05_Q,
		DI => MEM_IN,
		RDADDR => Std_logic_vector(Z04_ADDR),
		RDCLK => clk100,
		RDEN => VOICE_FILTQandF_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => MEM_WRADDR,
		WRCLK => clk100,
		WREN => VOICE_FILTQ_WREN);

	i_q_lpf : param_lpf Port Map(
		clk100 => clk100,

		ZN2_ADDR_IN => Z04_ADDR,
		Z00_PARAM_IN => signed(Z06_Q),
		Z01_ALPHA_IN => signed(SVF_ALPHA),
		Z00_PARAM_OUT => Z06_Q_LPF,

		initRam100 => initRam100,
		ram_rst100 => ram_rst100,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);

	-- filtq ram reposition
	i_filtq_ram_lpf : ram_controller_18k_18
	Port Map(
		DO => ZN1_Q_LPF,
		DI => Std_logic_vector(Z06_Q_LPF),
		RDADDR => Std_logic_vector(ZN2_ADDR),
		RDCLK => clk100,
		RDEN => VOICE_FILTQandF_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM18_WE,
		WRADDR => Std_logic_vector(Z06_ADDR),
		WRCLK => clk100,
		WREN => RAM_WREN);
	i_lp_ram : ram_controller_36k_25
	Port Map(
		DO => ZN2_LP_OUT,
		DI => Std_logic_vector(Z22_LP_IN),
		RDADDR => Std_logic_vector(ZN3_ADDR),
		RDCLK => clk100,
		RDEN => RAM_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM36_WE_DUB,
		WRADDR => Std_logic_vector(Z22_ADDR),
		WRCLK => clk100,
		WREN => RAM_WREN);

	i_bp_ram : ram_controller_36k_25
	Port Map(
		DO => ZN3_BP_OUT,
		DI => Std_logic_vector(Z27_BP_IN),
		RDADDR => Std_logic_vector(ZN4_ADDR),
		RDCLK => clk100,
		RDEN => RAM_RDEN,
		REGCE => RAM_REGCE,
		RST => ram_rst100,
		WE => RAM36_WE_DUB,
		WRADDR => Std_logic_vector(Z27_ADDR),
		WRCLK => clk100,
		WREN => RAM_WREN);

	poleloop :
	For pole In 0 To polecount - 1 Generate

		process_proc : Process (clk100)
		Begin
			If rising_edge(clk100) Then
				If initRam100 = '0' And OUTSAMPLEF_ALMOSTFULL = '0' Then

					-- propagate signals

					-- LP and BP are both "split" signals
					-- in that they include both old value and new value
					-- in a single array. the update is explicitly described here
					-- to avoid "multiply driven" error

					-- first lp is either read from memory or from output of previous oversample
					If pole = Z02_timeDiv Then -- Zn2 = z02 time div
						LP(pole)(ZN1) <= sfixed(ZN2_LP_OUT);
					Else
						LP(pole)(ZN1) <= LP(pole)(Z05);
					End If;
					lp_proploop :
					For propnum In LP(0)'low + 1 To LP(0)'high Loop
						LP(pole)(propnum) <= LP(pole)(propnum - 1);
					End Loop;

					-- the first BP is either read from ram (first oversample)
					If pole = Z01_timeDiv Then
						BP(pole)(ZN2) <= sfixed(ZN3_BP_OUT);
					Else -- or from the previous output (subsequant oversamples)
						BP(pole)(ZN2) <= resize(Z04_POSTF1(pole) + BP(pole)(Z04), BP(0)(0), fixed_saturate, fixed_truncate);
					End If;
					bp_proploop :
					For propnum In BP(0)'low + 1 To BP(0)'high Loop
						BP(pole)(propnum) <= BP(pole)(propnum - 1);
					End Loop;

					pole_proploop :
					For propnum In POLE_IN(0)'low + 1 To POLE_IN(0)'high Loop
						POLE_IN(pole)(propnum) <= POLE_IN(pole)(propnum - 1);
					End Loop;
					-- pole 0 is referred to explicitly here
					-- rather than outside of generate loop
					-- so that the arrays are not "multiply driven"
					If pole = 0 Then
						-- first pole, first oversample input from filter_in 
						POLE_IN(pole)(Z01) <= Z00_FILTER_IN;
					Else
						-- subsequent first oversamples from previous pole output
						POLE_IN(pole)(Z00) <= Z04_POLE_OUT(pole - 1);
					End If;

					-- read first f value from ram
					If pole = Z01_timeDiv Then
						F(pole)(ZN2) <= sfixed(ZN3_F_LPF);
					Else
						F(pole)(ZN2) <= F(pole)(Z04);
					End If;
					f_proploop :
					For propnum In F(0)'low + 1 To F(0)'high Loop
						F(pole)(propnum) <= F(pole)(propnum - 1);
					End Loop;

					-- read first q value from ram
					If pole = Z03_timeDiv Then
						Q(pole)(Z00) <= sfixed(ZN1_Q_LPF);
					Else
						Q(pole)(Z00) <= Q(pole)(Z06);
					End If;
					q_proploop :
					For propnum In Q(0)'low + 1 To Q(0)'high Loop
						Q(pole)(propnum) <= Q(pole)(propnum - 1);
					End Loop;

					-- the filter type is the only parameter in SVF which is not note-independant
					-- it is draw from the current instrument, which is set by the low 3 bits of
					-- the current address
					Z02_currinst(pole) <= Z01_ADDR - pole * 5;
					Z03_currtype(pole) <= FILT_FTYPE(to_integer(Z02_currinst(pole)(ramaddr_width - 1 Downto ramaddr_width - instcountlog2)), pole);
					Case Z03_currtype(pole) Is
						When FTYPE_NONE_I =>
							Z04_POLE_OUT(pole) <= POLE_IN(pole)(Z03);
						When FTYPE_BP_I =>
							Z04_POLE_OUT(pole) <= BP(pole)(Z03);
						When FTYPE_LP_I =>
							Z04_POLE_OUT(pole) <= LP(pole)(Z03);
						When Others =>
							Z04_POLE_OUT(pole) <= Z03_HP(pole);
					End Case;

					-- now we can begin the actual math processing
					-- POSTFs can be without saturation because F is on range [0,1]
					ZN1_POSTF0(pole) <= resize(BP(pole)(ZN2) * F(pole)(ZN2), ZN1_POSTF0(pole), fixed_wrap, fixed_truncate);
					LP(pole)(Z00) <= resize(LP(pole)(ZN1) + ZN1_POSTF0(pole), LP(pole)(Z00), fixed_saturate, fixed_truncate);
					Z02_SUM(pole) <= resize(POLE_IN(pole)(Z01) - LP(pole)(Z01), Z02_SUM(pole), fixed_saturate, fixed_truncate);
					Z02_POSTQ(pole) <= resize(BP(pole)(Z01) * Q(pole)(Z01), Z02_POSTQ(pole), fixed_saturate, fixed_truncate);
					Z03_HP(pole) <= resize(Z02_POSTQ(pole) + Z02_SUM(pole), Z03_HP(pole), fixed_saturate, fixed_truncate);
					Z04_POSTF1(pole) <= resize(Z03_HP(pole) * F(pole)(Z03), Z04_POSTF1(pole), fixed_wrap, fixed_truncate);
					BP(pole)(Z05) <= resize(Z04_POSTF1(pole) + BP(pole)(Z04), BP(pole)(Z05), fixed_saturate, fixed_truncate);

				End If;
			End If;
		End Process;
	End Generate;
End Behavioral;