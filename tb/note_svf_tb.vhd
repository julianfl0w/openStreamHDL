Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Library work;
Use work.memory_word_type.All;
Use work.fixed_pkg.All;

-- entity declaration for your testbench.Dont declare any ports here
Entity note_svf_tb Is
End note_svf_tb;

Architecture behavior Of note_svf_tb Is
	-- Component Declaration for the Unit Under Test (UUT)
	Component note_svf

		--just copy and paste the input and output ports of your module as such. 

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

	End Component;

	Component ram_active_rst Is
		Port (
			clkin : In Std_logic;
			clksrdy : In Std_logic;
			ram_rst : Out Std_logic := '0';
			initializeRam_out : Out Std_logic := '1'
		);
	End Component;

	Component interpolate_oversample_4 Is
		Port (
			clk100 : In Std_logic;

			ZN1_ADDR : In unsigned (RAMADDR_WIDTH - 1 Downto 0);
			Z01_INTERP_OUT : Out sfixed(1 Downto -std_flowwidth + 2) := (Others => '0');
			Z00_INTERP_IN : In sfixed(1 Downto -std_flowwidth + 2) := (Others => '0');

			ram_rst100 : In Std_logic;
			initRam100 : In Std_logic;
			OUTSAMPLEF_ALMOSTFULL : In Std_logic
		);
	End Component;

	-- Clock period definitions
	Constant clk100_period : Time := 10 ns;
	Signal clk100 : Std_logic := '0';

	Constant VOICENUM : Integer := 0;

	-- 10ms ~= 100 Hz
	Constant square_period : Time := 1 ms;
	Signal square : sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');
	Signal saw : sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');

	Signal ZN1_ADDR : unsigned (9 Downto 0) := (Others => '0');
	Signal ZN3_ADDR : unsigned (9 Downto 0) := (Others => '0');
	Signal ZN4_ADDR : unsigned (9 Downto 0) := (Others => '0');

	Signal Z21_FILTER_OUT : sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');

	Signal Z06_OS : oneshotspervoice_by_ramwidth18s := (Others => (Others => '0'));
	Signal Z06_COMPUTED_ENVELOPE : inputcount_by_ramwidth18s := (Others => (Others => '0'));

	Signal MEM_WRADDR : Std_logic_vector (9 Downto 0) := (Others => '0');
	Signal MEM_IN : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');
	Signal VOICE_FILTQ_WREN : Std_logic := '0';
	Signal VOICE_FILTF_WREN : Std_logic := '0';

	Signal FILT_FDRAW : instcount_by_polecount_by_drawslog2 := (Others => (Others => (Others => '0')));
	Signal FILT_QDRAW : instcount_by_polecount_by_drawslog2 := (Others => (Others => (Others => '0')));
	Signal FILT_FTYPE : instcount_by_polecount_by_ftypeslog2 := (Others => (Others => 0));

	Signal initRam100 : Std_logic;
	Signal ram_rst100 : Std_logic;
	Signal OUTSAMPLEF_ALMOSTFULL : Std_logic := '0';

	Signal clksrdy : Std_logic := '1';
	Signal SAMPLECOUNT : Integer := 0;

	Signal Z01_INTERP_OUT : sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');
	Signal Z00_INTERP_IN : sfixed(1 Downto -STD_FLOWWIDTH + 2) := (Others => '0');

	Constant INSTNUM : Integer := 0;

Begin
	-- Instantiate the Unit(s) Under Test
	i_note_svf : note_svf Port Map(
		clk100 => clk100,
		ZN5_ADDR => ZN4_ADDR,

		Z20_FILTER_OUT => Z21_FILTER_OUT,
		Z00_FILTER_IN => Z01_INTERP_OUT,

		Z05_OS => Z06_OS,
		Z05_COMPUTED_ENVELOPE => Z06_COMPUTED_ENVELOPE,

		MEM_WRADDR => MEM_WRADDR,
		MEM_IN => MEM_IN,
		VOICE_FILTQ_WREN => VOICE_FILTQ_WREN,
		VOICE_FILTF_WREN => VOICE_FILTF_WREN,
		FILT_FDRAW => FILT_FDRAW,
		FILT_QDRAW => FILT_QDRAW,
		FILT_FTYPE => FILT_FTYPE,

		ram_rst100 => ram_rst100,
		initRam100 => initRam100,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);

	i_ram_active_rst : ram_active_rst Port Map(
		clkin => clk100,
		clksrdy => clksrdy,
		ram_rst => ram_rst100,
		initializeRam_out => initRam100
	);

	i_interpolate_oversample_4 : interpolate_oversample_4 Port Map(
		clk100 => clk100,

		ZN1_ADDR => ZN1_ADDR,
		Z01_INTERP_OUT => Z01_INTERP_OUT,
		Z00_INTERP_IN => Z00_INTERP_IN,

		ram_rst100 => ram_rst100,
		initRam100 => initRam100,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);

	-- Clock process definitions( clock with 50% duty cycle is generated here.)
	clk100_process : Process
	Begin
		clk100 <= '0';
		Wait For clk100_period/2; --for 0.5 ns signal is '0'.
		clk100 <= '1';
		Wait For clk100_period/2; --for next 0.5 ns signal is '1'.

	End Process;

	timing_proc : Process (clk100)
	Begin
		If rising_edge(clk100) Then

			If OUTSAMPLEF_ALMOSTFULL = '0' Then
				ZN1_ADDR <= ZN1_ADDR + 1;
				ZN4_ADDR <= ZN1_ADDR + 4;
				ZN3_ADDR <= ZN4_ADDR;

				If unsigned(ZN1_ADDR) >= 0 And unsigned(ZN1_ADDR) < 4 Then
					-- frequency / 48e3  = thisadd / 2**24
					-- thisadd = frequency * 2**24 / 48e3
					saw <= resize(saw + to_sfixed(0.005, saw), saw, fixed_wrap, fixed_truncate);
					--                if SAW(SAW'high) = '1' then
					--                    Z00_FILTER_IN <= to_signed( 2**23, STD_FLOWWIDTH);
					--                else
					--                    Z00_FILTER_IN <= to_signed(-2**23, STD_FLOWWIDTH);
					--                end if;

					Z00_INTERP_IN <= SQUARE;
					--Z00_INTERP_IN <= resize(-signed(SAW), STD_FLOWWIDTH);
					--Z00_INTERP_IN <= to_signed(2**10, STD_FLOWWIDTH);
				Else
					Z00_INTERP_IN <= (Others => '0');
				End If;
			End If;

			SAMPLECOUNT <= SAMPLECOUNT + 1;
			--        if SAMPLECOUNT < 20 then
			--            OUTSAMPLEF_ALMOSTFULL <= '1';
			--        else
			--            OUTSAMPLEF_ALMOSTFULL <= '0';
			--        end if;

			If SAMPLECOUNT = 30 Then
				samplecount <= 0;
			End If;
		End If;
	End Process;

	-- generate a square wave
	square_proc : Process
	Begin
		square <= to_sfixed(2 ** 22, square);
		Wait For square_period/2;
		square <= to_sfixed(-2 ** 22, square);
		Wait For square_period/2;
	End Process;
	-- this simple test ensures basic functionality of the paramstate variable filter 

	note_svfproc : Process
	Begin
		Wait Until initRam100 = '0';
		-- create basic butterworth
		-- draw from constant

		pole_loop :
		For pole In 0 To polecount - 1 Loop
			FILT_FDRAW(INSTNUM, pole) <= to_unsigned(DRAW_FIXED_I, drawslog2);
			-- draw q from constant
			FILT_QDRAW(INSTNUM, pole) <= to_unsigned(DRAW_FIXED_I, drawslog2);
			-- FTYPE : lowpass
			FILT_FTYPE(INSTNUM, pole) <= FTYPE_BP_I;
		End Loop;

		FILT_FTYPE(INSTNUM, 3) <= FTYPE_LP_I;
		-- where F is [0,1] fixed point, 2**16 == 1
		-- f = 2*sin(pi* fc/ fs) * 2**16
		-- f = 2*sin(pi*.01) * 2**16

		MEM_WRADDR <= (Others => '0');
		MEM_IN <= Std_logic_vector(to_signed(4117, 18));
		VOICE_FILTF_WREN <= '1';
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		VOICE_FILTF_WREN <= '0';

		-- q is on scale 2**14 = 1
		-- -1/sqrt(2) is butterworth
		-- qc = 1/q
		-- so q = -2**14*sqrt(2) = -23170

		MEM_WRADDR <= (Others => '0');
		MEM_IN <= Std_logic_vector(to_signed(-23170, 18));
		VOICE_FILTQ_WREN <= '1';
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		MEM_WRADDR <= Std_logic_vector(unsigned(MEM_WRADDR) + 5);
		Wait Until rising_edge(clk100);
		VOICE_FILTQ_WREN <= '0';

		Wait;
	End Process;

End;