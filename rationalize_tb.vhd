Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Library work;
Use work.memory_word_type.All;

-- entity declaration for your testbench.Dont declare any ports here
Entity rationalize_tb Is
End rationalize_tb;

Architecture behavior Of rationalize_tb Is
	-- Component Declaration for the Unit Under Test (UUT)
	--just copy and paste the input and output ports of your module as such. 
	Component rationalize
		Port (
			clk100 : In Std_logic;

			ZN3_ADDR : In unsigned (RAMADDR_WIDTH - 1 Downto 0); -- Z01
			Z00_IRRATIONAL : In signed (ram_width18 - 1 Downto 0); -- Z01
			OSC_HARMONICITY_WREN : In Std_logic;
			OSC_HARMONICITY_ALPHA_WREN : In Std_logic;
			MEM_IN : In Std_logic_vector(ram_width18 - 1 Downto 0);
			MEM_WRADDR : In Std_logic_vector(RAMADDR_WIDTH - 1 Downto 0);

			Z02_RATIONAL_oscdet : Out Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');

			ALPHA_WRITE : In unsigned(5 Downto 0);

			initRam100 : In Std_logic;
			ram_rst100 : In Std_logic;
			OUTSAMPLEF_ALMOSTFULL : In Std_logic
		);
	End Component;
	Component ram_active_rst Is
		Port (
			clkin : In Std_logic;
			ram_rst : Out Std_logic;
			clksRdy : In Std_logic;
			initializeRam_out : Out Std_logic
		);
	End Component;

	-- Clock period definitions
	Constant clk100_period : Time := 10 ns;

	Signal clk100 : Std_logic := '0';

	Signal OUTSAMPLEF_ALMOSTFULL : Std_logic := '0';

	Signal ZN3_ADDR : unsigned (RAMADDR_WIDTH - 1 Downto 0) := (Others => '0'); -- Z01

	Signal OSC_HARMONICITY_WREN : Std_logic;
	Signal OSC_HARMONICITY_ALPHA_WREN : Std_logic;
	Signal MEM_IN : Std_logic_vector(ram_width18 - 1 Downto 0);
	Signal MEM_WRADDR : Std_logic_vector(RAMADDR_WIDTH - 1 Downto 0);

	Signal clksRdy : Std_logic := '1';
	Signal initRam100 : Std_logic;
	Signal ram_rst100 : Std_logic;

	Signal Z00_IRRATIONAL : signed (ram_width18 - 1 Downto 0) := (Others => '0');
	Signal Z02_RATIONAL_oscdet : Std_logic_vector(ram_width18 - 1 Downto 0) := (Others => '0');
	Signal ALPHA_WRITE : unsigned(5 Downto 0) := (Others => '0');

	Signal initTimer : Integer := 0;

Begin

	i_rationalize : rationalize Port Map(
		clk100 => clk100,

		ZN3_ADDR => ZN3_ADDR,
		Z00_IRRATIONAL => Z00_IRRATIONAL,
		OSC_HARMONICITY_WREN => OSC_HARMONICITY_WREN,
		OSC_HARMONICITY_ALPHA_WREN => OSC_HARMONICITY_ALPHA_WREN,
		MEM_IN => MEM_IN,
		MEM_WRADDR => MEM_WRADDR,

		Z02_RATIONAL_oscdet => Z02_RATIONAL_oscdet,

		ALPHA_WRITE => ALPHA_WRITE,

		initRam100 => initRam100,
		ram_rst100 => ram_rst100,
		OUTSAMPLEF_ALMOSTFULL => OUTSAMPLEF_ALMOSTFULL
	);

	i_ram_active_rst : ram_active_rst Port Map(
		clkin => clk100,
		ram_rst => ram_rst100,
		clksRdy => clksRdy,
		initializeRam_out => initRam100
	);

	-- Clock process definitions( clock with 50% duty cycle is generated here.
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
			ZN3_ADDR <= ZN3_ADDR + 1;
			--Z00_IRRATIONAL <= Z00_IRRATIONAL + 1;
			Z00_IRRATIONAL <= to_signed(2 ** 12, RAM_WIDTH18);
			--Z00_IRRATIONAL <= to_signed(21500, RAM_WIDTH18); 
		End If;
	End Process;

	init_proc : Process (clk100)
	Begin
		If rising_edge(clk100) Then
			OSC_HARMONICITY_WREN <= '0';
			OSC_HARMONICITY_ALPHA_WREN <= '0';
			If initRam100 = '0' Then
				initTimer <= initTimer + 1;
				MEM_WRADDR <= Std_logic_vector(to_unsigned(initTimer, MEM_WRADDR'length));
				If (initTimer < 1024) Then
					MEM_IN <= "000000000000010000";
					OSC_HARMONICITY_WREN <= '1';
				Elsif initTimer < 2048 Then
					OSC_HARMONICITY_ALPHA_WREN <= '1';
					MEM_IN <= "010000000000000000";
				End If;
			End If;
		End If;
	End Process;

End;