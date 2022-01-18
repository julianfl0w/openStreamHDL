Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;

Library ieee_proposed;
Use ieee_proposed.fixed_pkg.All;
Use ieee_proposed.fixed_float_types.All;

-- entity declaration for your testbench.Dont declare any ports here
Entity sine_lookup_tb Is
    Generic (
        phase_bw: integer := 32;
        process_bw: integer := 18
    );
End sine_lookup_tb;

Architecture behavior Of sine_lookup_tb Is
	-- Component Declaration for the Unit Under Test (UUT)

	Component sine_lookup

	End Component;
	Constant clk_period : Time := 10 ns;
	Signal clk : Std_logic := '0';
	--signal Z00_PHASE : sfixed(RAM_WIDTH18 - 1 downto 0) := (others=>'0');
	Signal Z00_PHASE : signed(phase_bw - 1 Downto 0) := (Others => '0');
	Signal Z06_SINE_out : sfixed(1 Downto -process_bw + 2) := (Others => '0');
    Signal run : Std_logic_vector(5 downto 0) := (others=>'1');
Begin
	-- Instantiate the Unit Under Test (UUT)
	i_sine_lookup : entity work.sine_lookup 
	Port Map(
		clk => clk,
		rst => '0',
		Z00_PHASE => Z00_PHASE, 
		Passthrough => '0',
		Z06_SINE_out => Z06_SINE_out,
		run => run
	);

	-- Clock process definitions( clock with 50% duty cycle is generated here.
	clk_process : Process
	Begin
		clk <= '0';
		Wait For clk_period/2; --for 0.5 ns signal is '0'.
		clk <= '1';
		Wait For clk_period/2; --for next 0.5 ns signal is '1'.
	End Process;

	lfotest : Process (clk)
	Begin
		If rising_edge(clk) Then
			Z00_PHASE <= Z00_PHASE + 21553;
			--Z00_PHASE <= Z00_PHASE + 1;
		End If;
	End Process;

End;